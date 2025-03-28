#!/usr/bin/perl

use strict;
use warnings;

# $ARGV[0]=filename of game
# $ARGV[1]=input type (file or stdin)
# $ARGV[2]=input file (only when $ARGV[1] eq 'file')
# $ARGV[3]=action (only when $ARGV[1] eq 'file')

require './load-and-validate-game.pl';

my $adventureDir='adventures/';
my $sessionDir='sessions/';

# 1=Stops when an action results in a failure. Handy during automated testing. 0=Normal behaviour.
my $debug = 0;

# 0=don't die when you are defeated by an enemy, 1=die when you are defeated
my $die = 0;

my $inputType=$ARGV[1];

my $INPUT;

if (-p STDIN) {
    $debug = 0;
}

my ($gameFile)='empty';
my $prefix='empty';
my $inputFile;

if($ARGV[0] eq 'Eldoria'){
    $gameFile='eldoria.txt';
    $prefix='eldoria-';
}
if($ARGV[0] eq 'PrisonEscape'){
    $gameFile='prison-escape.txt';
    $prefix='prison-escape-';
}
if($ARGV[0] eq 'HauntedMansion'){
    $gameFile='game_data.txt';
    $prefix='haunted-mansion-';
}

$gameFile=$adventureDir.$gameFile;
$prefix=$sessionDir.$prefix;

if (!(-e $gameFile)) {
    print "Game $gameFile not found";
    die "Game $gameFile not found\n";
}

if($inputType ne 'file'){
    $inputType='stdin';
}
else{
    $inputFile=$prefix.$ARGV[2];
    if(-e $inputFile){
        open($INPUT,$inputFile);
    }
    else{
        $inputType='argv';
    }
}

my %game_data = load_game_data($gameFile);

# Validate game data
validate_game_data(%game_data);

if($inputType eq 'file' || $inputType eq 'argv'){
    # Output game output to session file
    my($GAMEOUT);
    open($GAMEOUT,'>'.$ARGV[2]);
    select $GAMEOUT;
}

# Initial setup
my $current_room_id = $game_data{first_room_id};
my @inventory;
my @room_history;  # Stack to track room history
my $room_data;

# Track unlocked rooms
my %unlocked_rooms;

sub readInput{
    if($inputType eq 'stdin'){
        return lc(<STDIN>);
    }
    elsif($inputType eq 'file'){
        if(!eof($INPUT)){
            return lc(readline($INPUT));
        }
        else{
            $inputType='done';
            return lc($ARGV[3]);
        }
    }
    elsif($inputType eq 'argv'){
        $inputType='done';
        return lc($ARGV[3]);
    }
    else{
        exit;
    }
}

sub showRoomInfo{
    $room_data = $game_data{rooms}{$current_room_id};

    # Display room name and description with black text on white background
    print "\n\033[47m\033[30m--- Location: ", $room_data->{name}, " ---\033[0m\n";
    print "$room_data->{description}\n";

    # Simple inventory display in cyan
    if (@inventory) {
        print "\033[36mInventory: ", join(", ", @inventory), "\033[0m\n";  # Cyan text followed by reset
    }

    if ($room_data->{exits}) {
        my $options = [];
        foreach my $direction (sort keys %{$room_data->{exits}}) {
            if(exists $game_data{rooms}{$room_data->{exits}{$direction}}{name}){
                push @$options, "$direction (" . $game_data{rooms}{$room_data->{exits}{$direction}}{name}.')';
            }
            else{
                push @$options, $direction;
            }
        }
        print "Options: ", join(", ", @$options), "\n";
    }

    # Only display items in room if there are any
    my(@visibleItems);
    my($sourceRoom_data);
    if(exists $game_data{rooms}{$current_room_id}{sourceroom}){
        $sourceRoom_data=$game_data{rooms}{$game_data{rooms}{$current_room_id}{sourceroom}};
    }
    if (exists $sourceRoom_data->{items} && @{$sourceRoom_data->{items}}) {
        push(@visibleItems,@{$sourceRoom_data->{items}});
    }
    if (exists $room_data->{items} && @{$room_data->{items}}) {
        push(@visibleItems,@{$room_data->{items}});
    }
    if(@visibleItems){
        print "Visible items: ", join(", ", @visibleItems), "\n";
    }

    # Display persons in the room if any
    if ($room_data->{persons}) {
        print "Persons here: ", join(", ", @{$room_data->{persons}}), "\n";
    }
}

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
    print "- Examine: Check if items in your inventory contain other items with 'examine [item]'.\n";
    print "- Describe: Get a description of an item in your inventory using 'describe [item]'.\n";
    print "- Search: Find hidden items in a location with 'search [target]'.\n";
    print "- Combine: Create new items by combining two, e.g., 'combine [item1] and [item2]'.\n";
    print "- Drop: Remove an item from your inventory using 'drop [item]'.\n";
    print "- Ask: Interact with persons using 'ask [person] about [topic]'.\n";
    print "- Trade: Exchange items with persons using 'trade [item] with [person]'.\n";
    print "- Fight (Only when in a room with an enemy): Engage enemies with 'fight [enemy] with [item]'.\n";
    print "- Retreat (Only when in a room with an enemy): Move back to the previous room with 'retreat'.\n";
    print "- Inventory: View all items and their descriptions using 'inventory'.\n";  # New command description
    print "- Hint: Ask for hints on a subject using 'hint [subject]'.\n";  # New hint command description
    print "- Quit: Exit the game by typing 'quit'.\n";

    while (1) {
        showRoomInfo();
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
        my $action = readInput();
        if (!$action) {
            die "No more input!\n";
        } else {
            chomp($action);
        }
        if($debug || $inputType ne 'stdin'){
            print "\033[34m".$action."\033[0m\n\n";
        }

        handle_action($action);

    }

    print "\nThanks for playing!\n";
}

sub handle_puzzle {
    my $room_data = $game_data{rooms}{$current_room_id};

    # Display puzzle riddle in green
    print "\033[32m$room_data->{riddle}\033[0m\n";

    my $answer = readInput();
    if (!$answer) {
        die "No more input!\n";
    } else {
        chomp($answer);
    }
    if($debug || $inputType ne 'stdin'){
        print "\033[34m".$answer."\033[0m\n\n";
    }

    if ($answer eq $game_data{rooms}{$current_room_id}{answer}) {
        # Check if reward item is already in inventory
        unless (grep { $_ eq $room_data->{reward_item} } @inventory) {
            push @inventory, $room_data->{reward_item};
            print "You've given the correct answer and now have access to this location. As a reward you get a $room_data->{reward_item}!\n";
        } else {
            print "You already received this reward.\n";
        }

        # Display contained item description
        if (exists $game_data{items}{$room_data->{reward_item}}{description}) {
            print "$game_data{items}{$room_data->{reward_item}}{description}\n";
        }
        delete $game_data{rooms}{$current_room_id}->{puzzle};  # Remove puzzle after solving
	if($inputType eq 'done'){	
	    saveNewAction($answer);
	}
        showRoomInfo();
    } else {
        print "That is not correct. Try again.\n";
    }
}

sub handle_enemy {
    my $room_data = $game_data{rooms}{$current_room_id};
    my $enemy = $room_data->{enemy};

    print "You encounter a $enemy->{name}!\n\033[32mYou must fight it with the correct item to survive or retreat.\033[0m\n";

    my $action = readInput();
    if (!$action) {
        die "No more input!\n";
    } else {
        chomp($action);
    }
    if($debug || $inputType ne 'stdin'){
        print "\033[34m".$action."\033[0m\n\n";
    }

    if ($action =~ /^fight (.*?) with (.*)$/) {
        handle_fight($2);
        if($inputType eq 'done'){
            saveNewAction($action);
        }
    } elsif ($action =~ /^retreat$/) {
        handle_retreat();
        if($inputType eq 'done'){
            saveNewAction($action);
        }
    } else {
        print "I don't understand that action ($action). Try fighting with an item from your inventory or retreating.\n";
	exit;
        if ($debug) { die; }
    }
}

sub handle_fight {
    my $item = shift;
    my $room_data = $game_data{rooms}{$current_room_id};
    my $enemy = $room_data->{enemy};

    # Check if item is already in inventory
    if (grep { $_ eq $item } @inventory) {
        if ($item eq $enemy->{required_item}) {
            # Display defeat description in yellow
            if (exists $game_data{rooms}{$current_room_id}{defeat_description}) {
                print "\033[93m$game_data{rooms}{$current_room_id}{defeat_description}\033[0m\n";
            }
            print "You defeated the $enemy->{name}!\n";

            # Add reward item to inventory if it doesn't exist already
            if (exists $room_data->{reward_item}) {
                my $reward = $room_data->{reward_item};
                unless (grep { $_ eq $reward } @inventory) {
                    push @inventory, $reward;
                    print "You received a $reward as a reward!\n";

                    # Display contained item description
                    if (exists $game_data{items}{$reward}{description}) {
                        print "$game_data{items}{$reward}{description}\n";
                    }
                } else {
                    print "You already received this reward.\n";
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
            my $previous_room_id = pop @room_history;
            $current_room_id = $previous_room_id;
            showRoomInfo();

            if ($die) { exit; }  # End game loop
        }
    } else {
        print "You don't have a $item in your inventory.\n";
		my $previous_room_id = pop @room_history;
		$current_room_id = $previous_room_id;
		showRoomInfo();
    }
}

sub handle_retreat {
    if (@room_history) {
        my $previous_room_id = pop @room_history;
        $current_room_id = $previous_room_id;
        print "You retreat to the $game_data{rooms}{$current_room_id}{name}.\n";
        showRoomInfo();
    } else {
        print "There is no previous room to retreat to!\n";
    }
}

sub saveNewAction{
    my($action)=@_;
    if(-e $inputFile){
        close($INPUT);
    }
    open($INPUT,'>>'.$inputFile);
    print $INPUT $action."\n";
    close($INPUT);
}

sub handle_action {
    my ($action) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};
    my $validAction=1;

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
    } elsif ($action eq 'inventory') {
        handle_inventory();  # Handle inventory command
    } elsif ($action =~ /^hint (.*)$/) {  # New hint command
        handle_hint($1);
    } elsif ($action eq 'quit') {
        exit;
    } else {
        $validAction=0;
        print "I don't understand that action ($action). Try moving, taking an item, examining something, describing an item or your whole inventory, searching, combining items, dropping an item, trading with a person, asking a person a question or asking for a hint.\n";
        if ($debug) { die; }
    }
    if($inputType eq 'done' && $validAction){
        saveNewAction($action);
    }
}

sub handle_move {
    my ($action) = @_;
    my $next_room_id = $game_data{rooms}{$current_room_id}{exits}{$action};

    # Check if the room is locked
    if (exists $game_data{rooms}{$next_room_id}{locks} && !(exists $unlocked_rooms{$next_room_id})) {
        my %inventory_items = map { $_ => 1 } @inventory;
        my $unlocked = 0;

        foreach my $lock (@{ $game_data{rooms}{$next_room_id}{locks} }) {
            if (exists $inventory_items{$lock}) {
                $unlocked = 1;
                last;
            }
        }

        unless ($unlocked) {
            print "\033[31mThe door to ", $game_data{rooms}{$next_room_id}{name}, " is locked. You need a specific item.\033[0m\n";
            return; # Skip this exit
        } else {
            if (!$unlocked_rooms{$next_room_id}) {
                if($game_data{rooms}{$next_room_id}{unlock_texts}[0]){
                    print "\033[92m$game_data{rooms}{$next_room_id}{unlock_texts}[0]\033[0m\n";
                }
                else{
                    print "You used the $game_data{rooms}{$next_room_id}{locks}[0] to unlock the door.\n";
                }
                $unlocked_rooms{$next_room_id} = 1;
            }
        }
    }

    push @room_history, $current_room_id;  # Save current room before moving
    $current_room_id = $next_room_id;
}

sub handle_take {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};
    my ($sourceRoom_data);
    if(exists $game_data{rooms}{$current_room_id}{sourceroom}){
        $sourceRoom_data=$game_data{rooms}{$game_data{rooms}{$current_room_id}{sourceroom}};
    }
    
    if ((exists $room_data->{items} && grep { $_ eq $item } @{ $room_data->{items} }) || (exists $sourceRoom_data->{items} && grep { $_ eq $item } @{ $sourceRoom_data->{items} })) {
        # Check if item is already in inventory
        unless (grep { $_ eq $item } @inventory) {
            push @inventory, $item;
            print "You took the $item.\n";

            # Display item description
            if (exists $game_data{items}{$item}{description}) {
                print "$game_data{items}{$item}{description}\n";
            }

            @{$room_data->{items}} = grep { $_ ne $item } @{ $room_data->{items} };
            @{$sourceRoom_data->{items}} = grep { $_ ne $item } @{ $sourceRoom_data->{items} };
        } else {
            print "You already have that item in your inventory.\n";
        }
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
                # Only add if not already in inventory
                unless (grep { $_ eq $contained_item } @inventory) {
                    push @inventory, $contained_item;
                    print "You found a ", $contained_item, " in the $item.\n";

                    # Display searched item description
                    if (exists $game_data{items}{$contained_item}{description}) {
                        print "$game_data{items}{$contained_item}{description}\n";
                    }
                } else {
                    print "You already have the $contained_item in your inventory.\n";
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
            # Only add if not already in inventory
            unless (grep { $_ eq $item } @inventory) {
                push @inventory, $item;
                print "You found a ", $item, " in the $target.\n";

                # Display searched item description
                if (exists $game_data{items}{$item}{description}) {
                    print "$game_data{items}{$item}{description}\n";
                }
            } else {
                print "You already have that item in your inventory.\n";
            }
        }
    } else {
        print "There is nothing to find here.\n";
    }
}

sub handle_combine {
    my ($item1, $item2) = @_;

    # Check if both items are in inventory
    if ((grep { $_ eq $item1 } @inventory) && (grep { $_ eq $item2 } @inventory)) {
        if (exists $game_data{combine}{$item1}{$item2} || exists $game_data{combine}{$item2}{$item1}) {
            my $new_item;
            if (exists $game_data{combine}{$item1}{$item2}) {
                $new_item = $game_data{combine}{$item1}{$item2};
            } else {
                $new_item = $game_data{combine}{$item2}{$item1};
            }

            # Only add if not already in inventory
            unless (grep { $_ eq $new_item } @inventory) {
                push @inventory, $new_item;
                print "You combined the $item1 and $item2 to create a new item: ", $new_item, ".\n";

                # Display new item description
                if (exists $game_data{items}{$new_item}{description}) {
                    print "$game_data{items}{$new_item}{description}\n";
                }
            } else {
                print "You already have that item in your inventory.\n";
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
    my ($room_data);
    if(exists $game_data{rooms}{$current_room_id}{sourceroom}){
        $room_data=$game_data{rooms}{$game_data{rooms}{$current_room_id}{sourceroom}};
    }
    else{
        $room_data = $game_data{rooms}{$current_room_id};
    }

    if (grep { $_ eq $item } @inventory) {
        # Remove from inventory
        @inventory = grep { $_ ne $item } @inventory;
	push(@{$room_data->{items}},$item);
        print "You dropped the $item.\n";
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

                # Only add if not already in inventory
                unless (grep { $_ eq $reward } @inventory) {
                    push @inventory, $reward;
                    print "The $person answers: $game_data{persons}{$person}{answers}{$keyword}\n";
                    print "The $person gives you $reward.\n";

                    # Display reward item description
                    if (exists $game_data{items}{$reward}{description}) {
                        print "$game_data{items}{$reward}{description}\n";
                    }
                } else {
                    print "You already received that from this person.\n";
                }
                $answered = 1;
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

                # Only add if not already in inventory
                unless (grep { $_ eq $reward } @inventory) {
                    push @inventory, $reward;
                    print "The $person responds: $game_data{persons}{$person}{answers}{$item}\n";
                    print "The $person gives you $reward.\n";

                    # Remove the item from inventory
                    @inventory = grep { $_ ne $item } @inventory;

                    # Display reward item description
                    if (exists $game_data{items}{$reward}{description}) {
                        print "$game_data{items}{$reward}{description}\n";
                    }
                } else {
                    print "You already have that item.\n";
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

# New subroutine to handle the inventory command
sub handle_inventory {
    print "\033[36mInventory:\033[0m\n";  # Cyan text followed by reset
    if (@inventory) {
        foreach my $item (sort @inventory) {
            print "\033[1m$item: \033[0m";
            if (exists $game_data{items}{$item}{description}) {
                print "$game_data{items}{$item}{description}\n";
            } else {
                print "No description available.\n";
            }
        }
    } else {
        print "Your inventory is empty.\n";
    }
}

# New subroutine to handle the hint command
sub handle_hint {
    my ($subject) = @_;
    if (exists $game_data{hints}{$subject}) {
        print "Hint for '$subject': \n$game_data{hints}{$subject}\n";
    } else {
        print "No hints available for '$subject'.\n";
    }
}

# Start the game
start_game();
