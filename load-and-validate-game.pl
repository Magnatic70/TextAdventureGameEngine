# Load game data from file into a hash structure

sub process_config_line{
    my ($line)=@_;
    if ($line =~ /^RoomID:(.*)$/) {
        $current_room_id = $1;
        unless(exists $game_data{rooms}{$current_room_id}){
            $game_data{rooms}{$current_room_id} = {};
        }
        if(!exists $game_data{first_room_id}){
            $game_data{first_room_id}=$current_room_id;
        }
    } elsif ($line =~ /^Name:(.*)$/) {
        $game_data{rooms}{$current_room_id}{name} = $1;
    } elsif ($line =~ /^Description:(.*)$/) {
        my $desc=$1;
        $desc=~s/\<p\>/\n\n/g;
        $desc=~s/\<br\>/\n/g;
        $game_data{rooms}{$current_room_id}{description} = $desc;
    } elsif ($line =~ /^Exits:(.*)$/) {
        my @exits = split /,/, $1;
        my %exit_map;
        foreach my $exit (@exits) {
            if ($exit =~ /^(.*):(.*)$/) {
                $exit_map{$1} = $2;
            }
        }
        $game_data{rooms}{$current_room_id}{exits} = \%exit_map;
    } elsif ($line =~ /^SourceRoomID:(.*)$/){
        $game_data{rooms}{$current_room_id}{sourceroom} = $1;
    } elsif ($line =~ /^LoadModifier:(.*)$/){
        @{$game_data{rooms}{$current_room_id}{modifiers}} = split(',',$1);
    } elsif ($line =~ /^Items:(.*)$/) {
        my @items = split /,/, $1;
        if(exists $game_data{rooms}{$current_room_id}{items}){
            push(@{$game_data{rooms}{$current_room_id}{items}},@items);
        }
        else{
            $game_data{rooms}{$current_room_id}{items} = \@items if @items;
        }
    } elsif ($line =~ /^Persons:(.*)$/) {
        my @persons = split /,/, $1;
        $game_data{rooms}{$current_room_id}{persons} = \@persons if @persons;
    } elsif ($line =~ /^Locks:(.*)$/) {
        if(exists $game_data{rooms}{$current_room_id}{locks} && $1 eq '-'){
            delete $game_data{rooms}{$current_room_id}{locks};
        }
        else{
            $game_data{rooms}{$current_room_id}{locks} = [split /,/, $1] if $1 ne '-';
        }
    } elsif ($line =~ /^UnlockTexts:(.*)$/) {
        $game_data{rooms}{$current_room_id}{unlock_texts} = [split /;/, $1];
    } elsif ($line =~ /^UnlockHints:(.*)$/) {
        $game_data{rooms}{$current_room_id}{unlock_hints} = [split /;/, $1];
    } elsif ($line =~ /^Puzzle:(.*)$/) {
        $game_data{rooms}{$current_room_id}{puzzle} = $1;
    } elsif ($line =~ /^Riddle:(.*)$/) {
        $game_data{rooms}{$current_room_id}{riddle} = $1;
    } elsif ($line =~ /^RewardItem:(.*)$/) {
        $game_data{rooms}{$current_room_id}{reward_item} = $1 if (exists $game_data{rooms}{$current_room_id}{riddle} || exists $game_data{rooms}{$current_room_id}{enemy});
    } elsif ($line =~ /^Answer:(.*)$/) {
        $game_data{rooms}{$current_room_id}{answer} = $1;
    } elsif ($line =~ /^SearchableItems:(.*)$/) {
        $game_data{help}{search}=1;
        my @searchables = split /,/, $1;
        my %searchable_map=$game_data{rooms}{$current_room_id}{searchable_items};
        foreach my $searchable (@searchables) {
            if ($searchable =~ /^(.*):(.*)$/) {
                push @{$searchable_map{$1}}, $2;  # Allow multiple items per searchable target
            }
        }
        $game_data{rooms}{$current_room_id}{searchable_items} = \%searchable_map;
    } elsif ($line =~ /^Title:(.*)$/) {
        $game_data{title} = $1;
    } elsif ($line =~ /^\{Modifier:(.*)\}$/) {
        $current_modifier = $1;
        @{$game_data{modifiers}{$current_modifier}}=();
    } elsif ($line =~ /^WIP:(.*)$/) {
        $game_data{wip} = $1;
    } elsif ($line =~ /^Objective:(.*)$/) {
        $game_data{objective} = $1;
    } elsif ($line =~ /^FinalDestination:(.*)$/) {
        $game_data{final_destination} = $1;
    } elsif ($line =~ /^FinalMessage:(.*)$/) {
        $game_data{final_message} = $1;
    } elsif ($line =~ /^Item:(.*)$/) {
        $game_data{help}{item}=1;
        $current_item = $1;
    } elsif ($line =~ /^Contains:(.*)$/) {
        $game_data{help}{examine}=1;
        my @contains_items = split /,/, $1;
        $game_data{items}{$current_item}{contains} = \@contains_items if @contains_items;
    } elsif ($line =~ /^SplitsInto:(.*)$/) {
        $game_data{help}{deconstruct}=1;
        my @split_items = split /,/, $1;
        $game_data{items}{$current_item}{splits_into} = \@split_items if @split_items;
    } elsif ($line =~ /^Combine:(.*)$/) {
        $game_data{help}{combine}=1;
        my ($combine_from, $combine_to) = split /=/, $1;
        my ($item1, $item2) = split /,/, $combine_from;
        $game_data{combine}{$item1}{$item2} = $combine_to;
    } elsif ($line =~ /^DropLocation:(.*)$/) {
        my($roomID,$dropText)=split(':',$1);
        $game_data{items}{$current_item}{droplocations}{$roomID}=$dropText;
    } elsif ($line =~ /^RemoveItemFromLocation:(.*)$/) {
        my($item,$roomID)=split(':',$1);
        my $room_data = $game_data{rooms}{$roomID};
        my ($sourceRoom_data);
        if(exists $game_data{rooms}{$current_room_id}{sourceroom}){
            $sourceRoom_data=$game_data{rooms}{$game_data{rooms}{$current_room_id}{sourceroom}};
        }
        @{$room_data->{items}} = grep { $_ ne $item } @{ $room_data->{items} };
        @{$sourceRoom_data->{items}} = grep { $_ ne $item } @{ $sourceRoom_data->{items} };
    } elsif ($line =~ /^Enemy:(.*)$/) {
        $game_data{help}{enemy}=1;
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
    } elsif ($line =~ /^DisplayName:(.*)$/){
        $game_data{persons}{$current_person}{displayname}=$1;
    } elsif ($line =~ /^NegativeAskResponse:(.*)$/){
        $game_data{persons}{$current_person}{negativeaskresponse}=$1;
    } elsif ($line =~ /^NegativeTradeResponse:(.*)$/){
        $game_data{persons}{$current_person}{negativetraderesponse}=$1;
    } elsif ($line =~ /^NegativeGiveResponse:(.*)$/){
        $game_data{persons}{$current_person}{negativegiveresponse}=$1;
    } elsif ($line =~ /^Keywords:(.*)$/) {
        $game_data{help}{ask}=1;
        my %keywords_map;
        my %answers_map;
        foreach my $keyword_tripple (split /;/, $1) {
            if ($keyword_tripple =~ /^(.*?):(.*?):(.*?)$/) {
                $keywords_map{$1} = $2;
                $answers_map{$1} = $3;
            }
        }
        $game_data{persons}{$current_person}{keywords} = \%keywords_map;
        $game_data{persons}{$current_person}{askanswers} = \%answers_map;
    } elsif ($line =~ /^Accepts:(.*)$/) {
        $game_data{help}{give}=1;
        my %gift_responses_map;
        foreach my $accept_double (split /;/, $1) {
            if ($accept_double =~ /^(.*?):(.*?)$/) {
                $gift_responses_map{$1} = $2;
            }
        }
        $game_data{persons}{$current_person}{accept_responses} = \%gift_responses_map;
    } elsif ($line =~ /^Trades:(.*)$/) {
        $game_data{help}{trade}=1;
        my %trades_map;
        my %answers_map;
        foreach my $trade_tripple (split /;/, $1) {
            if ($trade_tripple =~ /^(.*?):(.*?):(.*?)$/) {
                $trades_map{$1} = $2;
                $answers_map{$1} = $3;
            }
        }
        $game_data{persons}{$current_person}{trades} = \%trades_map;
        $game_data{persons}{$current_person}{tradeanswers} = \%answers_map;
    } elsif ($line =~ /^Hint:(.*)$/) {
        $game_data{help}{hint}=1;
        my ($subject, $hint_text) = split /:/, $1, 2;
        $game_data{hints}{$subject} = $hint_text;
    } elsif ($line =~ /^AddToInventory:(.*)$/) {
        my @items=split(',',$1);
        foreach my $item (@items){
            unless (grep { $_ eq $item } @inventory) {
                push(@inventory,$item);
            }
        }
    } elsif ($line =~ /^RemoveFromInventory:(.*)$/) {
        my @items=split(',',$1);
        foreach my $item (@items){
            @inventory = grep { $_ ne $item } @inventory;
        }
    }
}

sub load_game_data {
    my $filename = shift;
    open my $fh, '<', $filename or die "Cannot open '$filename': $!";

    my ($current_room_id, $current_item, $current_person);  # Temporary variables to hold the current room ID and item/person names
    our($current_modifier);
    $current_modifier='--root--';

    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;  # Skip empty lines
        
        if ($line =~ /^\{\/Modifier\}$/) {
            $current_modifier = '--root--';
            next;
        }
        if($current_modifier eq '--root--'){
            process_config_line($line);
        }
        else{
            push(@{$game_data{modifiers}{$current_modifier}},$line);
        }
    }

    close $fh;
    if(!exists $game_data{wip}){
        $game_data{wip}='false';
    }
}

sub load_modifier_array {
    my $modifierName=shift;
    my ($current_room_id, $current_item, $current_person, $current_modifier);  # Temporary variables to hold the current room ID and item/person names

    foreach my $line (@{$game_data{modifiers}{$modifierName}}){
        process_config_line($line);
    }
}
    

# Validate game data for missing descriptions and undefined exits
sub validate_game_data {
    my (%game_data) = @_;

    # Check rooms for missing names or descriptions
    foreach my $room_id (keys %{ $game_data{rooms} }) {
        if (!exists $game_data{rooms}{$room_id}{name}) {
            warn "Room ID '$room_id' is missing a name.\n";
        }
        if (!exists $game_data{rooms}{$room_id}{description}) {
            warn "Room ID '$room_id' is missing a description.\n";
        }
        
        # Check for undefined sourceRoomID
        if(exists $game_data{rooms}{$room_id}{sourceroom}){
            unless (exists $game_data{rooms}{$game_data{rooms}{$room_id}{sourceroom}}){
                warn "SourceRoomID $$game_data{rooms}{$room_id}{sourceroom} for room $room_id does not exist\n";
            }
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
        else{
            warn "Room '$room_id' has no exits.\n";
        }
    }

    # Check items for missing descriptions
    foreach my $item_id (keys %{ $game_data{items} }) {
        if (!exists $game_data{items}{$item_id}{description}) {
            warn "Item '$item_id' is missing a description.\n";
            
            if (exists $game_data{items}{$item_id}{contains}){
                foreach my $contain_items ($game_data{items}{$item_id}{contains}){
                    foreach my $contain_item (@{$contain_items}){
                        unless (exists $game_data{items}{$contain_item}){
                            warn "Contains item '$contain_item' in item '$item_id' is not defined.\n";
                        }
                    }
                }
            }
        }
    }

    # Validate room items, search items, unlock items, puzzle or fight reward items, ask items, fight items and trade items
    foreach my $room_id (keys %{ $game_data{rooms} }) {
        if (exists $game_data{rooms}{$room_id}{reward_item}) {
            unless (exists $game_data{items}{$game_data{rooms}{$room_id}{reward_item}}) {
                warn "Reward item '$game_data{rooms}{$room_id}{reward_item}' in room '$room_id' is not defined.\n";
            }
        }

        if (exists $game_data{rooms}{$room_id}{enemy}) {
            my $required_item = $game_data{rooms}{$room_id}{enemy}{required_item};
            unless (exists $game_data{items}{$required_item}) {
                warn "Required item '$required_item' for enemy in room '$room_id' is not defined.\n";
            }
        }

        if (exists $game_data{rooms}{$room_id}{items}){
            foreach my $room_item (@{$game_data{rooms}{$room_id}{items}}){
                unless (exists $game_data{items}{$room_item}){
                    warn "Item '$room_item' in room '$room_id' is not defined.\n";
                }
            }
        }
        
        if (exists $game_data{rooms}{$room_id}{persons}){
            foreach my $person (@{$game_data{rooms}{$room_id}{persons}}){
                unless (exists $game_data{persons}{$person}){
                    warn "Person '$person' in room '$room_id' is not defined.\n";
                }
            }
        }
        
        if (exists $game_data{rooms}{$room_id}{locks}){
            foreach my $lock_item (@{$game_data{rooms}{$room_id}{locks}}){
                unless (exists $game_data{items}{$lock_item}){
                    warn "Unlock item '$lock_item' in room '$room_id' is not defined.\n";
                }
                unless (exists $game_data{rooms}{$room_id}{unlock_texts}){
                    warn "Unlock text for '$lock_item' in room '$room_id' is not defined.\n";
                }
            }
        }
        
        if(exists $game_data{rooms}{$room_id}{searchable_items}){
            foreach my $search_items (values %{$game_data{rooms}{$room_id}{searchable_items}}){
                foreach my $search_item (@{$search_items}){
                    unless (exists $game_data{items}{$search_item}){
                        warn "Searchable item '$search_item' in room '$room_id' is not defined.\n";
                    }
                }
            }
        }
    }

    foreach my $person_id (keys %{ $game_data{persons} }) {
        if (exists $game_data{persons}{$person_id}{keywords}) {
            foreach my $keyword (keys %{ $game_data{persons}{$person_id}{keywords} }) {
                my $reward_item = $game_data{persons}{$person_id}{keywords}{$keyword};
                unless (exists $game_data{items}{$reward_item}) {
                    warn "Keyword reward item '$reward_item' for person '$person_id' is not defined.\n";
                }
            }
        }

        if (exists $game_data{persons}{$person_id}{trades}) {
            foreach my $trade (keys %{ $game_data{persons}{$person_id}{trades} }) {
                my $reward_item = $game_data{persons}{$person_id}{trades}{$trade};
                unless (exists $game_data{items}{$reward_item}) {
                    warn "Trade reward item '$reward_item' for person '$person_id' is not defined.\n";
                }
            }
        }
    }
}

1;
