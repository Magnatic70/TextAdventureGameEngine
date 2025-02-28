#!/usr/bin/perl

use strict;
use warnings;

# Load game data from file into a hash structure
sub load_game_data {
    my $filename = shift;
    open my $fh, '<', $filename or die "Cannot open '$filename': $!";
    
    my %game_data;
    my ($current_room, $current_item);  # Temporary variables to hold the current room and item names

    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;  # Skip empty lines

        if ($line =~ /^Room:(.*)$/) {
            $current_room = $1;
            $game_data{$current_room} = {};
        } elsif ($line =~ /^Description:(.*)$/) {
            $game_data{$current_room}{description} = $1;
        } elsif ($line =~ /^Exits:(.*)$/) {
            my @exits = split /,/, $1;
            my %exit_map;
            foreach my $exit (@exits) {
                if ($exit =~ /^(.*):(.*)$/) {
                    $exit_map{$1} = $2;
                }
            }
            $game_data{$current_room}{exits} = \%exit_map;
        } elsif ($line =~ /^Items:(.*)$/) {
            my @items = split /,/, $1;
            $game_data{$current_room}{items} = \@items if @items;
        } elsif ($line =~ /^Locks:(.*)$/) {
            $game_data{$current_room}{locks} = [split /,/, $1];
        } elsif ($line =~ /^Puzzle:(.*)$/) {
            $game_data{$current_room}{puzzle} = $1;
        } elsif ($line =~ /^Riddle:(.*)$/) {
            $game_data{$current_room}{riddle} = $1;
        } elsif ($line =~ /^Answer:(.*)$/) {
            $game_data{$current_room}{answer} = $1;
        } elsif ($line =~ /^FinalDestination:(.*)$/) {
            $game_data{final_destination} = $1;
        } elsif ($line =~ /^Item:(.*)$/) {
            $current_item = $1;
            $game_data{$current_item} = {};
        } elsif ($line =~ /^Contains:(.*)$/) {
            my @contains_items = split /,/, $1;
            $game_data{$current_item}{contains} = \@contains_items if @contains_items;
        }
    }

    close $fh;
    return %game_data;
}

# Main game loop
sub start_game {
    my %game_data = load_game_data('game_data.txt');

    # Initial setup
    my $current_room = 'Entrance';
    my @inventory;

    print "Welcome to the Adventure Game!\n";
    
    while (1) {
        my $room_data = $game_data{$current_room};
        
        # Display room description and available actions
        print "\n--- Room: $current_room ---\n";
        print "$room_data->{description}\n";

        if ($room_data->{exits}) {
            print "Exits: ", join(", ", keys %{$room_data->{exits}}), "\n";
        }
        
        if (exists $room_data->{items}) {
            print "Items in room: ", join(", ", @{ $room_data->{items} }), "\n";
        }

        # Check for puzzles
        if (exists $room_data->{puzzle}) {
            print "$room_data->{riddle}\n";
            chomp(my $answer = <STDIN>);
            if ($answer eq $game_data{$current_room}{answer}) {
                push @inventory, 'book';
                print "You solved the puzzle and found a book!\n";
                delete $room_data->{puzzle};  # Remove puzzle after solving
            } else {
                print "That is not correct. Try again.\n";
                next;
            }
        }

        # Check if current room is the final destination
        if ($current_room eq $game_data{final_destination}) {
            print "\nCongratulations! You've reached the final destination: $current_room!\n";
            last;  # Exit the game loop
        }

        # Prompt for user action
        print "\nWhat do you want to do? ";
        chomp(my $action = <STDIN>);
        
        if (exists $room_data->{exits} && exists $room_data->{exits}{$action}) {
            my $next_room = $room_data->{exits}{$action};
            
            # Check if the room is locked
            if ($game_data{$next_room}{locks}) {
                my %inventory_items = map { $_ => 1 } @inventory;
                my $unlocked = 0;

                foreach my $lock (@{ $game_data{$next_room}{locks} }) {
                    if (exists $inventory_items{$lock}) {
                        print "You used the $lock to unlock the door.\n";
                        $unlocked = 1;
                        last;
                    }
                }

                unless ($unlocked) {
                    print "The door to the $next_room is locked. You need a specific item.\n";
                    next; # Skip this exit
                }
            }
            
            $current_room = $next_room;
        } elsif ($action =~ /^take (.*)$/) {
            my $item = $1;
            if (exists $room_data->{items} && grep { $_ eq $item } @{ $room_data->{items} }) {
                push @inventory, $item;
                print "You took the $item.\n";
                @{$room_data->{items}} = grep { $_ ne $item } @{ $room_data->{items} };
            } else {
                print "There is no such item here.\n";
            }
        } elsif ($action =~ /^examine (.*)$/) {
            my $item = $1;
            if (grep { $_ eq $item } @inventory) {
                if (exists $game_data{$item}{contains}) {
                    foreach my $contained_item (@{ $game_data{$item}{contains} }) {
                        push @inventory, $contained_item;
                        print "You found a $contained_item inside the $item.\n";
                    }
                } else {
                    print "The $item doesn't seem to contain anything special.\n";
                }
            } else {
                print "You don't have a $item in your inventory.\n";
            }
        } elsif ($action eq 'quit') {
            last;
        } else {
            print "I don't understand that action. Try moving, taking an item, or examining something.\n";
        }

        # Simple inventory display
        if (@inventory) {
            print "\nInventory: ", join(", ", @inventory), "\n";
        }
    }

    print "\nThanks for playing!\n";
}

# Start the game
start_game();
