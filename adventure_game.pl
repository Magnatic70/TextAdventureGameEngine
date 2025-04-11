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

my $inputType='stdin';
if($ARGV[1]){
    $inputType=$ARGV[1];
}

my $INPUT;

if (-p STDIN || (exists $ENV{'DEBUG_AGE'} && $ENV{'DEBUG_AGE'}==1)) {
    $debug = 1;
}

my ($gameFile)='empty';
my $prefix='empty';
my $inputFile;

my($CFG,@header,$line,@gameMapping,%gameMapping,$gm);
open($CFG,'games.cfg');
while($line=readline($CFG)){
    chomp($line);
    if(!@header){
        @header=split(';',$line);
        if($header[1] ne 'shortName'){
            die "ERROR: games.cfg should contain displayName;shortName;fileName as the first line. All following lines should contain this informatie for each game.\n";
        }
    }
    else{
        @gameMapping=split(';',$line);
        if($ARGV[0] eq $gameMapping[1]){
            $gameFile=$gameMapping[2];
            $prefix=lc($gameMapping[0]).'-';
            $prefix=~s/ /-/g;
        }
    }
}
close($CFG);

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

my %game_data;
%game_data=load_game_data($gameFile);

# Validate game data
if($debug){
    validate_game_data(%game_data);
}

if($inputType eq 'file' || $inputType eq 'argv'){
    # Output game output to session file
    my($GAMEOUT);
    open($GAMEOUT,'>/tmp/'.$ARGV[2]);
    select $GAMEOUT;
}

# Initial setup
my $current_room_id = $game_data{first_room_id};
my @inventory;
my @room_history;  # Stack to track room history
my $room_data;
my @loadedModFiles; # Keep track of all loaded modifiers

# Track unlocked rooms
my %unlocked_rooms;

sub readInput{
    my $input=readRawInput();
    chomp($input);
    $input=~s/ +$//g;
    return lc($input);
}

sub readRawInput{
    if($inputType eq 'stdin'){
        my $input=<STDIN>;
        if($input){
            return lc($input);
        }
        else{
            return;
        }
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
    print "$room_data->{description}\n\n";

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
        my @roompersons;
        foreach my $person (@{$room_data->{persons}}){
            if($game_data{persons}{$person}{displayname}){
                push(@roompersons,$game_data{persons}{$person}{displayname});
            }
            else{
                push(@roompersons,$person);
            }
        }
        print "Persons here: ". join(", ", @roompersons), "\n";
    }
}

sub handle_help{
    # Explain all possible actions
    print "\nMovement actions:\n";
    print "- Use directions like 'north', 'south', etc., to move between locations.\n";
    print "     See the options of a location for available movement actions.\n\n";
    print "Inventory actions:\n";
    print "- Take:        Pick up items using 'take [item]'.\n";
    print "- Examine:     Check if items in your inventory contain other items with 'examine [item]'.\n";
    print "- Combine:     Create new items by combining two, e.g., 'combine [item1] and [item2]'.\n";
    print "- Deconstruct: Try to split an item in your inventory using 'deconstruct [item]'.\n";
    print "- Describe:    Get a description of an item in your inventory using 'describe [item]'.\n";
    print "- Inventory:   View all items and their descriptions using 'inventory'.\n";  # New command description
    print "- Drop:        Remove an item from your inventory using 'drop [item]'.\n\n";
    print "Interact with the environment:\n";
    print "- Search:      Find hidden items in a location with 'search [target]'.\n";
    print "- Ask:         Interact with persons using 'ask [person] about [topic]'.\n";
    print "- Trade:       Exchange items with persons using 'trade [item] with [person]'.\n";
    print "- Fight:       Only when in a room with an enemy. Engage enemies with 'fight [enemy] with [item]'.\n";
    print "- Retreat:     Only when in a room with an enemy. Move back to the previous room with 'retreat'.\n\n";
    print "General actions\n";
    print "- Hint:        Ask for hints on a subject using 'hint [subject]'.\n";  # New hint command description
    print "- Help:        Shows this list of available actions.\n";
    if($inputType eq 'stdin'){
        print "- Quit:        Exit the game by typing 'quit'.\n";
    }
}

sub loadModifier{
    my($modFile)=@_;
    unless (grep { $_ eq $modFile } @loadedModFiles){
        %game_data=load_game_data($adventureDir.$modFile);
        if($debug){
            validate_game_data(%game_data);
        }
        push(@loadedModFiles,$modFile);
    }
}

# Main game loop
sub start_game {
    print "\n\033[97;1;4m$game_data{title}\033[0m\n";
    if ($game_data{objective}) {
        print "$game_data{objective}\n";
    }

    handle_help();

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
        
        # Check if a modifier file should be loaded
        if ($game_data{rooms}{$current_room_id}{modifier_file}){
            loadModifier($game_data{rooms}{$current_room_id}{modifier_file});
        }

        # Prompt for user action with green text
        if($game_data{wip} eq 'true' && !$debug){
            print "\033[32mWhat do you want to do? (This is a Work in Progress, it might still contain errors)\033[0m\n";  # Green text followed by reset
        }
        else{
            print "\033[32mWhat do you want to do? \033[0m\n";  # Green text followed by reset
        }
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
        if($room_data->{reward_item}){
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
        }
        else{
            print "You answer was correct! You can now perform actions in this location.\n";
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
            else{
                print "You have died!\n";
            }
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
    } elsif ($action =~ /^deconstruct (.*)$/) {
        handle_deconstruct($1);
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
    } elsif ($action eq 'help'){
        handle_help();
    } elsif ($action eq 'quit' && $inputType eq 'stdin') {
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
        my @unlockHints;
        my $lockIndex=0;

        foreach my $lock (@{ $game_data{rooms}{$next_room_id}{locks} }) {
            if (exists $inventory_items{$lock}) {
                $unlocked = 1;
                last;
            }
            else{
                if(exists $game_data{rooms}{$next_room_id}{unlock_hints}){
                    push(@unlockHints,${ $game_data{rooms}{$next_room_id}{unlock_hints} }[$lockIndex]);
                }
            }
            $lockIndex++;
        }

        unless ($unlocked) {
            if($#unlockHints>=0){
                print "\033[31m";
                foreach my $unlockHint (@unlockHints){
                    print $unlockHint."\n";
                }
                print "\033[0m";
            }
            else{
                print "\033[31mThe door to ", $game_data{rooms}{$next_room_id}{name}, " is locked. You need a specific item.\033[0m\n";
            }
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

sub handle_deconstruct {
    my ($item) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};

    if (grep { $_ eq $item } @inventory) {
        if (exists $game_data{items}{$item}{splits_into}) {
            foreach my $split_item (@{ $game_data{items}{$item}{splits_into} }) {
                # Only add if not already in inventory
                unless (grep { $_ eq $split_item } @inventory) {
                    push @inventory, $split_item;
                    print "You deconstructed ", $split_item, " from the $item.\n";

                    # Display searched item description
                    if (exists $game_data{items}{$split_item}{description}) {
                        print "  $game_data{items}{$split_item}{description}\n";
                    }
                } else {
                    print "You already have the $split_item in your inventory.\n";
                }
            }
            # Remove split item from inventory
            @inventory = grep { $_ ne $item } @inventory;
        } else {
            print "The $item doesn't deconstruct into parts.\n";
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

                # Display searched item description
                if (exists $game_data{items}{$item}{description}) {
                    print "Found: $game_data{items}{$item}{description}\n";
                }
                else{
                    print "Found: $item\n";
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

sub determineActualPerson{
    my($room_data,$person)=@_;
    my($actualPerson,$displayName);
    foreach my $testPerson (@{$room_data->{persons}}){
        if($game_data{persons}{$testPerson}{displayname} && lc($game_data{persons}{$testPerson}{displayname}) eq $person){
            $actualPerson=$testPerson;
            $displayName=$game_data{persons}{$testPerson}{displayname};
        }
        elsif($testPerson eq $person){
            $actualPerson=$testPerson;
            $displayName=$testPerson;
        }
    }
    return ($actualPerson,$displayName);
}

sub handle_ask {
    my ($person, $question) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};
    
    my ($actualPerson,$displayName)=determineActualPerson($room_data,$person); # We might need to translate from displayname to personID
    if ($actualPerson) {
        my $answered = 0;
        # Check for keywords in the question
        foreach my $keyword (keys %{$game_data{persons}{$actualPerson}{keywords}}) {
            if ($question =~ /\b$keyword\b/) {
                my $reward = $game_data{persons}{$actualPerson}{keywords}{$keyword};

                # Only add if not already in inventory
                unless (grep { $_ eq $reward } @inventory) {
                    push @inventory, $reward;
                    print "$displayName: \"$game_data{persons}{$actualPerson}{askanswers}{$keyword}\"\n";
                    # Display reward item description
                    if (exists $game_data{items}{$reward}{description}) {
                        print "Gives you: $game_data{items}{$reward}{description}\n";
                    }
                    else{
                        print "Gives you $reward.\n";
                    }

                } else {
                    print "You already received that from this person.\n";
                }
                $answered = 1;
            }
        }
        if (!$answered) {
            if($game_data{persons}{$actualPerson}{negativeaskresponse}){
                print "$displayName: ".'"'.$game_data{persons}{$actualPerson}{negativeaskresponse}.'"'."\n";
            }
            else{
                print "$displayName: \"I don't know the answer to this question.\"\n";
            }
        }
    } else {
        print "There is no such person here.\n";
    }
}

sub handle_trade {
    my ($item, $person) = @_;
    my $room_data = $game_data{rooms}{$current_room_id};
    my $displayName;

    my($actualPerson,$displayName)=determineActualPerson($room_data,$person); # We might need to translate from displayname to personID

    if ($actualPerson) {
        my $traded = 0;

        # Check for items
        foreach my $trade (keys %{$game_data{persons}{$actualPerson}{trades}}) {
            if ($item eq $trade) {
                my $reward = $game_data{persons}{$actualPerson}{trades}{$item};

                # Only add if not already in inventory
                unless (grep { $_ eq $reward } @inventory) {
                    push @inventory, $reward;
                    print "$displayName: \"$game_data{persons}{$actualPerson}{tradeanswers}{$item}\"\n";
                    # Display reward item description
                    if (exists $game_data{items}{$reward}{description}) {
                        print "Gives you: $game_data{items}{$reward}{description}\n";
                    }
                    else{
                        print "Gives you: $reward.\n";
                    }

                    # Remove the item from inventory
                    @inventory = grep { $_ ne $item } @inventory;

                } else {
                    print "You already have that item.\n";
                }
                $traded = 1;
            }
        }
        if (!$traded) {
            if($game_data{persons}{$actualPerson}{negativetraderesponse}){
                print "$displayName: ".'"'.$game_data{persons}{$actualPerson}{negativetraderesponse}.'"'."\n";
            }
            else{
                print "$displayName: \"I don't want to trade for $item.\"\n";
            }
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
