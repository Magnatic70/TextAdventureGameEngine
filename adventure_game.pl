#!/usr/bin/perl

use strict;
use warnings;

# 1=Stops when an action results in a failure. Handy during automated testing. 0=Normal behaviour.
my $debug = 0;

# 0=don't die when you are defeated by an enemy, 1=die when you are defeated
my $die = 0;

if (-p STDIN) {
    $debug = 1;
}

# Load game data from file into a hash structure
sub load_game_data {
    my $filename = shift;
    open my $fh, '<', $filename or die "Cannot open '$filename': $!";

    my %game_data;
    my ($current_room_id, $current_item, $current_person);  # Temporary variables to hold the current room ID and item/person names

    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;  # Skip empty lines

        if ($line =~ /^RoomID:(.*)$/) {
            $current_room_id = $1;
            $game_data{rooms}{$current_room_id} = {};
            if(!exists $game_data{first_room_id}){
                $game_data{first_room_id}=$current_room_id;
            }
        } elsif ($line =~ /^Title:(.*)$/) {
            $game_data{title} = $1;
        } elsif ($line =~ /^Objective:(.*)$/) {
            $game_data{objective} = $1;
        } elsif ($line =~ /^Name:(.*)$/) {
            $game_data{rooms}{$current_room_id}{name} = $1;
        } elsif ($line =~ /^Description:(.*)$/) {
            $game_data{rooms}{$current_room_id}{description} = $1;
        } elsif ($line =~ /^Exits:(.*)$/) {
            my @exits = split /,/, $1;
            my %exit_map;
            foreach my $exit (@exits) {
                if ($exit =~ /^(.*):(.*)$/) {
                    $exit_map{$1} = $2;
                }
            }
            $game_data{rooms}{$current_room_id}{exits} = \%exit_map;
        } elsif ($line =~ /^Items:(.*)$/) {
            my @items = split /,/, $1;
            $game_data{rooms}{$current_room_id}{items} = \@items if @items;
        } elsif ($line =~ /^Persons:(.*)$/) {
            my @persons = split /,/, $1;
            $game_data{rooms}{$current_room_id}{persons} = \@persons if @persons;
        } elsif ($line =~ /^Locks:(.*)$/) {
            $game_data{rooms}{$current_room_id}{locks} = [split /,/, $1];
        } elsif ($line =~ /^Puzzle:(.*)$/) {
            $game_data{rooms}{$current_room_id}{puzzle} = $1;
        } elsif ($line =~ /^Riddle:(.*)$/) {
            $game_data{rooms}{$current_room_id}{riddle} = $1;
        } elsif ($line =~ /^RewardItem:(.*)$/) {
            $game_data{rooms}{$current_room_id}{reward_item} = $1 if (exists $game_data{rooms}{$current_room_id}{riddle} || exists $game_data{rooms}{$current_room_id}{enemy});
        } elsif ($line =~ /^Answer:(.*)$/) {
            $game_data{rooms}{$current_room_id}{answer} = $1;
        } elsif ($line =~ /^FinalDestination:(.*)$/) {
            $game_data{final_destination} = $1;
        } elsif ($line =~ /^Item:(.*)$/) {
            $current_item = $1;
            $game_data{items}{$current_item} = {};
        } elsif ($line =~ /^Contains:(.*)$/) {
            my @contains_items = split /,/, $1;
            $game_data{items}{$current_item}{contains} = \@contains_items if @contains_items;
        } elsif ($line =~ /^Combine:(.*)$/) {
            my ($combine_from, $combine_to) = split /=/, $1;
            my ($item1, $item2) = split /,/, $combine_from;
            $game_data{combine}{$item1}{$item2} = $combine_to;
        } elsif ($line =~ /^SearchableItems:(.*)$/) {
            my @searchables = split /,/, $1;
            my %searchable_map;
            foreach my $searchable (@searchables) {
                if ($searchable =~ /^(.*):(.*)$/) {
                    push @{$searchable_map{$1}}, $2;  # Allow multiple items per searchable target
                }
            }
            $game_data{rooms}{$current_room_id}{searchable_items} = \%searchable_map;
        } elsif ($line =~ /^Enemy:(.*)$/) {
            my ($enemy, $required_item) = split /:/, $1;
            $game_data{rooms}{$current_room_id}{enemy} = { name => $enemy, required_item => $required_item };
        } elsif ($line =~ /^DefeatDescription:(.*)$/) {
            $game_data{rooms}{$current_room_id}{defeat_description} = $1 if exists $game_data{rooms}{$current_room_id}{enemy};
        } elsif ($line =~ /^DiedDescription:(.*)$/) {
            $game_data{rooms}{$current_room_id}{died_description} = $1 if exists $game_data{rooms}{$current_room_id}{enemy};
        } elsif ($line =~ /^ItemDescription:(.*)$/) {
            $game_data{items}{$current_item}{description} = $1;
        } elsif ($line =~ /^Person:(.*)$/) {
            $current_person = $1;
            $game_data{persons}{$current_person} = {};
        } elsif ($line =~ /^Keywords:(.*)$/) {
            my %keywords_map;
            my %answers_map;
            foreach my $keyword_tripple (split /;/, $1) {
                if ($keyword_tripple =~ /^(.*?):(.*?):(.*?)$/) {
                    $keywords_map{$1} = $2;
                    $answers_map{$1} = $3;
                }
            }
            $game_data{persons}{$current_person}{keywords} = \%keywords_map;
            $game_data{persons}{$current_person}{answers} = \%answers_map;
        } elsif ($line =~ /^Trades:(.*)$/) {
            my %trades_map;
            my %answers_map;
            foreach my $trade_tripple (split /,/, $1) {
                if ($trade_tripple =~ /^(.*?):(.*?):(.*?)$/) {
                    $trades_map{$1} = $2;
                    $answers_map{$1} = $3;
                }
            }
            $game_data{persons}{$current_person}{trades} = \%trades_map;
            $game_data{persons}{$current_person}{answers} = \%answers_map;
        }
    }

    close $fh;
    return %game_data;
}

# Validate game data for missing descriptions and undefined exits
sub validate_game_data {
    my ($game_data) = @_;

    # Check rooms for missing names or descriptions
    foreach my $room_id (keys %{ $game_data{rooms} }) {
        if (!exists $game_data{rooms}{$room_id}{name}) {
            warn "Room ID '$room_id' is missing a name.\n";
        }
        if (!exists $game_data{rooms}{$room_id}{description}) {
            warn "Room ID '$room_id' is missing a description.\n";
        }

        # Check exits for undefined room IDs
        if (exists $game_data{rooms}{$room_id}{exits}) {
            foreach my $exit_dir (keys %{ $game_data{rooms}{$room_id}{exits} }) {
                my $target_room_id = $game_data{rooms}{$room_id}{exits}{$exit_dir};
                unless (exists $game_data{rooms}{$target_room_id}) {
                    warn "Exit from room '$room_id' via '$exit_dir' leads to undefined room ID '$target_room_id'.\n";
                }
            }
        }
    }

    # Check items for missing descriptions
    foreach my $item_id (keys %{ $game_data{items} }) {
        if (!exists $game_data{items}{$item_id}{description}) {
            warn "Item '$item_id' is missing a description.\n";
        }
    }

    # Check persons for missing names or keywords
    foreach my $person_id (keys %{ $game_data{persons} }) {
        if (!exists $game_data{persons}{$person_id}{keywords}) {
            warn "Person '$person_id' is missing keywords.\n";
        }
    }
}

# Main game loop
sub start_game {
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
    validate_game_data(\%game_data);

    # Initial setup
    my $current_room_id = $game_data{first_room_id};
    my @inventory;
    my @room_history;  # Stack to track room history

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
            print "Items in room: ", join(", ", @{ $room_data->{items} }), "\n";
        }

        # Display persons in the room if any
        if ($room_data->{persons}) {
            print "Persons here: ", join(", ", @{$room_data->{persons}}), "\n";
        }

        # Check for puzzles
        if (exists $room_data->{puzzle}) {
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
                next;
            }
        }

        # Check for enemies
        if (exists $room_data->{enemy}) {
            my $enemy = $room_data->{enemy};
            print "You encounter a $enemy->{name}!\n\033[32mYou must fight it with the correct item to survive or retreat.\033[0m\n";

            my $action = <STDIN>;
            if (!$action) {
                die "No more input!\n";
            } else {
                chomp($action);
            }

            if ($action =~ /^fight (.*?) with (.*)$/) {
                my ($verb, $item) = ($1, $2);
                if (grep { $_ eq $item } @inventory) {
                    if ($item eq $enemy->{required_item}) {
                        # Display defeat description in yellow
                        if (exists $room_data->{defeat_description}) {
                            print "\033[93m$room_data->{defeat_description}\033[0m\n";
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
                        if (exists $room_data->{died_description}) {
                            print "\033[31m$room_data->{died_description}\033[0m\n";
                        }
                        print "You have died!\n";

                        if ($die) { last; }  # End game loop
                    }
                } else {
                    print "You don't have a $item in your inventory.\n";
                }
            } elsif ($action =~ /^retreat$/) {
                if (@room_history) {
                    my $previous_room_id = pop @room_history;
                    $current_room_id = $previous_room_id;
                    print "You retreat to the $game_data{rooms}{$current_room_id}{name}.\n";
                } else {
                    print "There is no previous room to retreat to!\n";
                }
            } else {
                print "I don't understand that action ($action). Try fighting with an item from your inventory or retreating.\n";
                if ($debug) { die; }
            }
            next;
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

        if (exists $room_data->{exits} && exists $room_data->{exits}{$action}) {
            my $next_room_id = $room_data->{exits}{$action};

            # Check if the room is locked
            if ($game_data{rooms}{$next_room_id}{locks}) {
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
                    next; # Skip this exit
                }
            }

            push @room_history, $current_room_id;  # Save current room before moving
            $current_room_id = $next_room_id;
        } elsif ($action =~ /^take (.*)$/) {
            my $item = $1;
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
        } elsif ($action =~ /^examine (.*)$/) {
            my $item = $1;
            if (grep { $_ eq $item } @inventory) {
                if (exists $game_data{items}{$item}{contains}) {
                    foreach my $contained_item (@{ $game_data{items}{$item}{contains} }) {
                        push @inventory, $contained_item;
                        print "You found a ", $contained_item, " in the $item.\n";

                        # Display contained item description
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
        } elsif ($action =~ /^describe (.*)$/) {  # New command to describe an item
            my $item = $1;
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
        } elsif ($action =~ /^search (.*)$/) {
            my $target = $1;
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
        } elsif ($action =~ /^combine (.*) and (.*)$/) {
            my ($item1, $item2) = ($1, $2);
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
        } elsif ($action =~ /^drop (.*)$/) {  # New command to drop an item
            my $item = $1;
            if (grep { $_ eq $item } @inventory) {
                push @{ $room_data->{items} }, $item;  # Add the dropped item back to the room's items
                print "You dropped the $item.\n";

                # Remove the item from inventory
                @inventory = grep { $_ ne $item } @inventory;
            } else {
                print "You don't have a $item in your inventory.\n";
                if ($debug) { die; }
            }
        } elsif ($action =~ /^ask (.*) about (.*)$/) {  # New command to ask persons questions
            my ($person, $question) = ($1, $2);
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
        } elsif ($action =~ /^trade (.*) with (.*)$/) {  # New command to ask persons questions
            my ($item, $person) = ($1, $2);
            if (grep { $_ eq $person } @{$room_data->{persons}}) {
                my $traded = 0;

                # Check for items
                foreach my $trade (keys %{$game_data{persons}{$person}{trades}}) {
                    if ($item eq $trade) {
                        my $reward = $game_data{persons}{$person}{trades}{$item};
                        push @inventory, $reward;
                        print "The $person responds: $game_data{persons}{$person}{answers}{$item}\n";
                        print "The $person gives you $reward.\n";
                        $traded = 1;

                        # Remove the item from inventory
                        @inventory = grep { $_ ne $item } @inventory;

                        # Display reward item description
                        if (exists $game_data{items}{$reward}{description}) {
                            print "$game_data{items}{$reward}{description}\n";
                        }
                    }
                }
                if (!$traded) {
                    print "The $person doesn't want to trade for $item.\n";
                }
            } else {
                print "There is no such person here.\n";
            }
        } elsif ($action eq 'quit') {
            last;
        } else {
            print "I don't understand that action ($action). Try moving, taking an item, examining something, describing an item, searching, combining items, dropping an item, or asking a person a question.\n";
            if ($debug) { die; }
        }
    }

    print "\nThanks for playing!\n";
}

# Start the game
start_game();
