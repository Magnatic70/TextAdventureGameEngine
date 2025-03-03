#!/usr/bin/perl

use strict;
use warnings;

require './load-and-validate-game.pl';

# 1=Stops when an action results in a failure. Handy during automated testing. 0=Normal behaviour.
my $debug = 0;

# 0=don't die when you are defeated by an enemy, 1=die when you are defeated
my $die = 0;

if (-p STDIN) {
    $debug = 1;
}

my ($gameFile);
if ($ARGV[0]) {
    $gameFile = $ARGV[0] . '.txt';
} else {
    print "Game not found, using default\n";
    $gameFile = 'game_data.txt';
}

if (!(-e $gameFile)) {
    print "Game not found, using default\n";
    $gameFile = 'game_data.txt';
}

my %game_data = load_game_data($gameFile);

# Validate game data
validate_game_data(%game_data);

# Initial setup
my $current_room_id = $game_data{first_room_id};
my @inventory;
my @room_history;  # Stack to track room history

# Main game loop
sub start_game {
    print "\n\033[97;1;4m$game_data{title}\033[0m\n";
    if ($game_data{objective}) {
        print "$game_data{objective}\n";
    }

    # Explain all possible actions
    print "\nYou can perform the following actions:\n";
    print "- Move: Use directions like 'north', 'south', etc., to move between locations.\n";
    print "- Take: Pick up items using 'take [item]'.\n";
    print "- Examine: Look at items with 'examine [item]'.\n";
    print "- Describe: Get a description of an item using 'describe [item]'.\n";
    print "- Search: Find hidden items with 'search [target]'.\n";
    print "- Combine: Create new items by combining two, e.g., 'combine [item1] and [item2]'.\n";
    print "- Drop: Remove an item from your inventory using 'drop [item]'.\n";
    print "- Ask: Interact with persons using 'ask [person] about [topic]'.\n";
    print "- Trade: Exchange items with persons using 'trade [item] with [person]'.\n";
    print "- Fight: Engage enemies with 'fight [enemy] with [item]'.\n";
    print "- Retreat: Move back to the previous room with 'retreat'.\n";
    print "- Quit: Exit the game by typing 'quit'.\n";

    while (1) {
        my $room_data = $game_data{rooms}{$current_room_id};

        # Display room name and description with black text on white background
        print "\n\n\033[47m\033[30m--- Location: ", $room_data->{name}, " ---\033[0m\n";
        print "$room_data->{description}\n";

        # Simple inventory display in cyan
        if (@inventory) {
            print "\033[36mInventory: ", join(", ", @inventory), "\033[0m\n";  # Cyan text followed by reset
        }

        if ($room_data->{exits}) {
            print "Options: ", join(", ", keys %{$room_data->{exits}}), "\n";
        }

        # Only display items in room if there are any
        if (exists $room_data->{items} && @{$room_data->{items}}) {
            print "Visible items: ", join(", ", @{ $room_data->{items} }), "\n";
        }

        # Display persons in the room if any
        if ($room_data->{persons}) {
            print "Persons here: ", join(", ", @{$room_data->{persons}}), "\n";
        }

        # Check for puzzles
        if (exists $room_data->{puzzle}) {
            handle_puzzle();
        }

        # Check for enemies
        if (exists $room_data->{enemy}) {
            handle_enemy();
        }

        # Check if current room is the final destination
        if ($current_room_id eq $game_data{final_destination}) {
            print "\n\033[92;6mCongratulations! You've won the game!\033[0m\n";
            last;  # Exit game loop
        }

        # Prompt for user action with green text
        print "\033[32mWhat do you want to do? \033[0m\n";  # Green text followed by reset
        my $action = <STDIN>;
        if (!$action) {
            die "No more input!\n";
        } else {
            chomp($action);
        }

        handle_action($action);

    }

    print "\nThanks for playing!\n";
}

sub handle_puzzle {
    my $room_data = $game_data{rooms}{$current_room_id};

    # Display puzzle riddle in green
    print "\033[32m$room_data->{riddle}\033[0m\n";

    my $answer = <STDIN>;
    if (!$answer) {
        die "No more input!\n";
    } else {
        chomp($answer);
    }

    if ($answer eq $game_data{rooms}{$current_room_id}{answer}) {
        push @inventory, $room_data->{reward_item};
        print "You solved the puzzle and found a $room_data->{reward_item}!\n";

        # Display contained item description
        if (exists $game_data{items}{$room_data->{reward_item}}{description}) {
            print "$game_data{items}{$room_data->{reward_item}}{description}\n";
        }
        delete $room_data->{puzzle};  # Remove puzzle after solving
    } else {
        print "That is not correct. Try again.\n";
    }
}

sub handle_enemy {
    my $room_data = $game_data{rooms}{$current_room_id};
    my $enemy = $room_data->{enemy};

    print "You encounter a $enemy->{name}!\n\033[32mYou must fight it with the correct item to survive or retreat.\033[0m\n";

    my $action = <STDIN>;
    if (!$action) {
        die "No more input!\n";
    } else {
        chomp($action);
    }

    if ($action =~ /^fight (.*?) with (.*)$/) {
        handle_fight($2);
    } elsif ($action =~ /^retreat$/) {
        handle_retreat();
    } else {
        print "I don't understand that action ($action). Try fighting with an item from your inventory or retreating.\n";
        if ($debug) { die; }
    }
}

sub handle_fight {
    my $item = shift;
    my $room_data = $game_data{rooms}{$current_room_id};
    my $enemy = $room_data->{enemy};

    if (grep { $_ eq $item } @inventory) {
        if ($item eq $enemy->{required_item}) {
            # Display defeat description in yellow
            if (exists $game_data{rooms}{$current_room_id}{defeat_description}) {
                print "\033[93m$game_data{rooms}{$current_room_id}{defeat_description}\033[0m\n";
            }
            print "You defeated the $enemy->{name}!\n";

            # Add reward item to inventory
            if (exists $room_data->{reward_item}) {
                push @inventory, $room_data->{reward_item};
                print "You received a $room_data->{reward_item} as a reward!\n";

                # Display contained item description
                if (exists $game_data{items}{$room_data->{reward_item}}{description}) {
                    print "$game_data{items}{$room_data->{reward_item}}{description}\n";
                }
            }
            delete $room_data->{enemy};  # Remove enemy after defeating
        } else {
            print "That item is not effective against the $enemy->{name}.\n";

            # Display DiedDescription in red if it exists
            if (exists $game_data{rooms}{$current_room_id}{died_description}) {
                print "\033[31m$game_data{rooms}{$current_room_id}{died_description}\033[0m\n";
            }
            print "You have died!\n";

            if ($die) { exit; }  # End game loop
        }
    } else {
        print "You don't have a $item in your inventory.\n";
    }
}

sub handle_retreat {
    if (@room_history) {
        my $previous_room_id = pop @room_history;
        $current_room_id = $previous_room_id;
        print "You retreat to the $game_data{rooms}{$current_room_id}{name}.\n";
    } else {
        print "There is no previous room to retreat to!\n";
    }
}

sub handle_action {
    my ($action) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (exists $room_data->{exits} && exists $room_data->{exits}{$action}) {
        handle_move($action);
    } elsif ($action =~ /^take (.*)$/) {
        handle_take($1);
    } elsif ($action =~ /^examine (.*)$/) {
        handle_examine($1);
    } elsif ($action =~ /^describe (.*)$/) {  # New command to describe an item
        handle_describe($1);
    } elsif ($action =~ /^search (.*)$/) {
        handle_search($1);
    } elsif ($action =~ /^combine (.*) and (.*)$/) {
        handle_combine($1, $2);
    } elsif ($action =~ /^drop (.*)$/) {  # New command to drop an item
        handle_drop($1);
    } elsif ($action =~ /^ask (.*) about (.*)$/) {  # New command to ask persons questions
        handle_ask($1, $2);
    } elsif ($action =~ /^trade (.*) with (.*)$/) {  # New command to trade items with persons
        handle_trade($1, $2);
    } elsif ($action eq 'quit') {
        exit;
    } else {
        print "I don't understand that action ($action). Try moving, taking an item, examining something, describing an item, searching, combining items, dropping an item, or asking a person a question.\n";
        if ($debug) { die; }
    }
}

sub handle_move {
    my ($action) = @_;
    my $next_room_id = $game_data{rooms}{$current_room_id}{exits}{$action};

    # Check if the room is locked
    if (exists $game_data{rooms}{$next_room_id}{locks}) {
        my %inventory_items = map { $_ => 1 } @inventory;
        my $unlocked = 0;

        foreach my $lock (@{ $game_data{rooms}{$next_room_id}{locks} }) {
            if (exists $inventory_items{$lock}) {
                print "You used the $lock to unlock the door.\n";
                $unlocked = 1;
                last;
            }
        }

        unless ($unlocked) {
            print "\033[31mThe door to ", $game_data{rooms}{$next_room_id}{name}, " is locked. You need a specific item.\033[0m\n";
            return; # Skip this exit
        }
    }

    push @room_history, $current_room_id;  # Save current room before moving
    $current_room_id = $next_room_id;
}

sub handle_take {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (exists $room_data->{items} && grep { $_ eq $item } @{ $room_data->{items} }) {
        push @inventory, $item;
        print "You took the $item.\n";

        # Display item description
        if (exists $game_data{items}{$item}{description}) {
            print "$game_data{items}{$item}{description}\n";
        }

        @{$room_data->{items}} = grep { $_ ne $item } @{ $room_data->{items} };
    } else {
        print "There is no such item here.\n";
        if ($debug) { die; }
    }
}

sub handle_examine {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $item } @inventory) {
        if (exists $game_data{items}{$item}{contains}) {
            foreach my $contained_item (@{ $game_data{items}{$item}{contains} }) {
                push @inventory, $contained_item;
                print "You found a ", $contained_item, " in the $item.\n";

                # Display searched item description
                if (exists $game_data{items}{$contained_item}{description}) {
                    print "$game_data{items}{$contained_item}{description}\n";
                }
            }
        } else {
            print "The $item doesn't seem to contain anything special.\n";
        }
    } else {
        print "You don't have a $item in your inventory.\n";
        if ($debug) { die; }
    }
}

sub handle_describe {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $item } @inventory) {
        if (exists $game_data{items}{$item}{description}) {
            print "$game_data{items}{$item}{description}\n";
        } else {
            print "You don't have a description for the $item.\n";
        }
    } elsif (exists $room_data->{items} && grep { $_ eq $item } @{ $room_data->{items} }) {
        if (exists $game_data{items}{$item}{description}) {
            print "$game_data{items}{$item}{description}\n";
        } else {
            print "You don't have a description for the $item.\n";
        }
    } else {
        print "There is no such item here or in your inventory.\n";
    }
}

sub handle_search {
    my ($target) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (exists $room_data->{searchable_items} && exists $room_data->{searchable_items}{$target}) {
        foreach my $item (@{ $room_data->{searchable_items}{$target} }) {
            push @inventory, $item;
            print "You found a ", $item, " in the $target.\n";

            # Display searched item description
            if (exists $game_data{items}{$item}{description}) {
                print "$game_data{items}{$item}{description}\n";
            }
        }
    } else {
        print "There is nothing to find here.\n";
    }
}

sub handle_combine {
    my ($item1, $item2) = @_;

    if ((grep { $_ eq $item1 } @inventory) && (grep { $_ eq $item2 } @inventory)) {
        if (exists $game_data{combine}{$item1}{$item2} || exists $game_data{combine}{$item2}{$item1}) {
            my $new_item;
            if (exists $game_data{combine}{$item1}{$item2}) {
                $new_item = $game_data{combine}{$item1}{$item2};
            } else {
                $new_item = $game_data{combine}{$item2}{$item1};
            }

            push @inventory, $new_item;
            print "You combined the $item1 and $item2 to create a new item: ", $new_item, ".\n";

            # Display new item description
            if (exists $game_data{items}{$new_item}{description}) {
                print "$game_data{items}{$new_item}{description}\n";
            }

            # Remove the original items from inventory
            @inventory = grep { $_ ne $item1 && $_ ne $item2 } @inventory;
        } else {
            print "These items cannot be combined.\n";
            if ($debug) { die; }
        }
    } else {
        print "You don't have both items in your inventory.\n";
        if ($debug) { die; }
    }
}

sub handle_drop {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $item } @inventory) {
        push @{ $room_data->{items} }, $item;  # Add the dropped item back to the room's items
        print "You dropped the $item.\n";

        # Remove the item from inventory
        @inventory = grep { $_ ne $item } @inventory;
    } else {
        print "You don't have a $item in your inventory.\n";
        if ($debug) { die; }
    }
}

sub handle_ask {
    my ($person, $question) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $person } @{$room_data->{persons}}) {
        my $answered = 0;
        # Check for keywords in the question
        foreach my $keyword (keys %{$game_data{persons}{$person}{keywords}}) {
            if ($question =~ /\b$keyword\b/) {
                my $reward = $game_data{persons}{$person}{keywords}{$keyword};
                push @inventory, $reward;
                print "The $person answers: $game_data{persons}{$person}{answers}{$keyword}\n";
                print "The $person gives you $reward.\n";
                $answered = 1;

                # Display reward item description
                if (exists $game_data{items}{$reward}{description}) {
                    print "$game_data{items}{$reward}{description}\n";
                }
            }
        }
        if (!$answered) {
            print "The $person doesn't know the answer to this question.\n";
        }
    } else {
        print "There is no such person here.\n";
    }
}

sub handle_trade {
    my ($item, $person) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $person } @{$room_data->{persons}}) {
        my $traded = 0;

        # Check for items
        foreach my $trade (keys %{$game_data{persons}{$person}{trades}}) {
            if ($item eq $trade) {
                my $reward = $game_data{persons}{$person}{trades}{$item};
                push @inventory, $reward;
                print "The $person responds: $game_data{persons}{$person}{answers}{$item}\n";
                print "The $person gives you $reward.\n";

                # Remove the item from inventory
                @inventory = grep { $_ ne $item } @inventory;

                # Display reward item description
                if (exists $game_data{items}{$reward}{description}) {
                    print "$game_data{items}{$reward}{description}\n";
                }
                $traded = 1;
            }
        }
        if (!$traded) {
            print "The $person doesn't want to trade for $item.\n";
        }
    } else {
        print "There is no such person here.\n";
    }
}

# Start the game
start_game();
