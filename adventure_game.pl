#!/usr/bin/perl

use strict;
use warnings;

# Load game data from file into a hash structure
sub load_game_data {
    my $filename = shift;
    open my $fh, '<', $filename or die "Cannot open '$filename': $!";
    
    my %game_data;
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;  # Skip empty lines

        if ($line =~ /^Room:(.*)$/) {
            my $room_name = $1;
            $game_data{$room_name} = {};
        } elsif ($line =~ /^Description:(.*)$/) {
            $game_data{$_}{description} = $1;
        } elsif ($line =~ /^Exits:(.*)$/) {
            $game_data{$_}{exits} = [split /,/, $1];
        } elsif ($line =~ /^Items:(.*)$/) {
            my @items = split /,/, $1;
            $game_data{$_}{items} = \@items if @items;
        } elsif ($line =~ /^Locks:(.*)$/) {
            $game_data{$_}{locks} = [split /,/, $1];
        } elsif ($line =~ /^Puzzle:(.*)$/) {
            $game_data{$_}{puzzle} = $1;
        } elsif ($line =~ /^Riddle:(.*)$/) {
            $game_data{$_}{riddle} = $1;
        } elsif ($line =~ /^Answer:(.*)$/) {
            $game_data{$_}{answer} = $1;
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
        print "$room_data->{description}\n";

        # Display available exits and items
        if (@{ $room_data->{exits} }) {
            print "Exits: ", join(", ", @{ $room_data->{exits} }), "\n";
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

        # Handle user input for movement or interaction
        chomp(my $action = <STDIN>);
        
        if ($action =~ /^(north|south|east|west)$/) {
            my @valid_exits = @{ $room_data->{exits} };
            if (grep { $_ eq $action } @valid_exits) {
                # Determine the new room dynamically based on exits
                foreach my $exit_dir (@{$room_data->{exits}}) {
                    for my $room_name (keys %game_data) {
                        if (exists $game_data{$room_name}{exits} && grep { $_ eq $exit_dir } @{$game_data{$room_name}{exits}}) {
                            # Check if the room is locked
                            my $next_room = $room_name;
                            if ($game_data{$next_room}{locks}) {
                                my %inventory_items = map { $_ => 1 } @inventory;
                                unless (grep { $inventory_items{$_} } @{$game_data{$next_room}{locks}}) {
                                    print "The door to the $next_room is locked. You need a specific item.\n";
                                    next; # Skip this exit
                                }
                            }
                            
                            $current_room = $next_room;
                        }
                    }
                }
            } else {
                print "You can't move in that direction.\n";
            }
        } elsif ($action =~ /^take (.*)$/) {
            my $item = $1;
            if (exists $room_data->{items} && grep { $_ eq $item } @{ $room_data->{items} }) {
                push @inventory, $item;
                print "You took the $item.\n";
                @{$room_data->{items}} = grep { $_ ne $item } @{ $room_data->{items} };
            } else {
                print "There is no such item here.\n";
            }
        } elsif ($action eq 'quit') {
            last;
        } else {
            print "I don't understand that action. Try moving or taking an item.\n";
        }

        # Simple inventory display
        if (@inventory) {
            print "Inventory: ", join(", ", @inventory), "\n";
        }
    }

    print "Thanks for playing!\n";
}

# Start the game
start_game();
