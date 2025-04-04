# Text Adventure Game Engine
The Adventure Game Engine (AGE) is a program for playing and creating classic text-based adventure games. You can create your own adventures by configuring them through simple text files, making it accessible without coding experience.

It started out as an experiment on how far I could push a local LLM into writing and expanding a more or less complex program. But I also started to have fun with it and wrote a few adventures. Some friends and collegues tried them and had fun playing them. So I decided to publish it on Github, hoping that more people can enjoy it.

If you just want to play a game made with this game engine, go to https://remote.magnatic.com/age/

# Features
* Create interactive stories with multiple locations and items
* Implement puzzles that require combining objects or searching environments
* Design conversations with non-player characters
* Support for combat scenarios
* Simple configuration format allows rapid prototyping of adventures

# Basic Gameplay Commands
Players can use these commands to interact with the game world:
* Move: north, south, east, west, etc.
* Take: take [item]
* Examine: examine [item] - check items in inventory for hidden contents
* Describe: describe [item] - get a detailed description of an item
* Search: search [target] - find hidden objects
* Combine: combine [item1] and [item2]
* Drop: drop [item]
* Ask: ask [person] about [topic]
* Trade: trade [item] with [person]
* Inventory: inventory - get detailled descriptions of all items in the inventory
* Fight: fight [enemy] with [item]
* Retreat (during combat)
* Get hints: hint [subject]

# Game Modes
1. **Plain Perl Program**: Run directly from the command line and play an adventure: `./adventure_game.pl <game name>`
2. **Debug Mode**: Use for automated testing by piping test steps to the engine: `cat <test steps> | ./adventure_game.pl <game name>` (stops at unknown commands/items)
3. **Browser Frontend**: Run the backend and access through a web browser at `http://<your ip>:4545`
   - First start: `python3 app.py`
4. **Docker Container**: Create with `./build-docker.sh` and run with `./start-docker.sh`
   - You'll find the frontend in your web browser at `http://<your ip>:4546`

# Configuration
## Configuration Structure
Adventures are built using a configuration file that defines the game world. The main components are:
- Title
- Objective
- Final Destination
- Items
- Persons
- Rooms (Locations)
- Hints

## Title
Define the title of the game.
```
Title:<brief title>
```

## Objective
Defines the goal of the game, shown at the start.
```
Objective:<text to brief the player on the adventure they are going to embark on>
```

## Work in progress
When set to true, shows a message to the player that the adventure is work in progress. Remove the line when your adventure is ready.
```
WIP:true
```

## Item Configuration
Items can be found by taking, receiving as gifts, trading, combining or through searching.

```
Item:<short item name>
ItemDescription:<detailed description when acquired>
Contains:<item to find when examined> (optional)
Combine:<item1>,<item2>=<resulting item> (optional)
```

Example:
```
Item:rusty key
ItemDescription:A tarnished iron key, covered in rust. It looks like it might fit an old lock.
Contains:small gear
Combine:small gear,wire=makeshift lockpick
```

## Person Configuration
Persons can give items based on questions asked and offer trades.

```
Person:<personID or short name>
DisplayName:<name of person that will be displayed to the player> (optional)
Keywords:<topic>:<gift item>;<topic2>:<gift item2>;... (optional)
Trades:<player offered item>:<person gives item>:<response> (optional)
NegativeAskResponse:<response when asking about something they don't know about> (optional)
NegativeTradeResponse:<response for trade they are not interested in> (optional)
```

Example:
```
Person:omh
DisplayName:Old Man Hemlock
Keywords:secret passage:map;treasure:gold coin
Trades:apple pie:small potion:Ah, you shouldn't have! But I appreciate the gesture.
NegativeAskResponse:I don't know, but maybe the butcher does.
NegativeTradeResonse:Sorry, I'm not interested in that right now. Maybe later.
```

## Room Configuration
Rooms define locations with descriptions and connections to other rooms. The first location you define in the config will be the location the player starts their adventure.

```
RoomID:<unique room identifier>
Name:<name displayed to player>
Description:<room description>
Exits:<direction/action>:<RoomID>,... (mandatory)
SourceRoomID:<original room ID for cloning/resetting> (optional)
Persons:<person1>,<person2>,... (optional)
Items:<item1>,<item2>,... (optional)
SearchableItems:<target>:<item>,... (optional)
Locks:<required item> (optional)
UnlockTexts:<message when first entering with unlock item> (mandatory if Locks is defined)
Puzzle:<text introduction> (optional, mutually exclusive with Enemy)
Riddle:<question> (mandatory if Puzzle is defined)
Answer:<correct answer> (mandatory if Puzzle is defined)
RewardItem:<item given for correct answer> (optional if Puzzle is defined)
Enemy:<enemy name>:<required weapon> (optional, mutually exclusive with Puzzle)
DefeatDescription:<message when player wins fight> (mandatory if Enemy is defined)
DiedDescription:<message when player loses fight> (mandatory if Enemy is defined)
RewardItem:<item given for winning a fight> (mandatory if Enemy is defined)
ModifierFile:<filename with modifiers> (optional)
```

Example:
```
RoomID:forest_entrance
Name:Forest Entrance
Description:You stand at the edge of a dark forest. The trees loom tall and silent.
Exits:north:clearing,east:path,west:village
Items:worn map
SearchableItems:ground:berries

RoomID:clearing
Name:Small Clearing
Description:A small clearing in the woods with wildflowers growing everywhere.
SourceRoomID:forest_entrance
Exits:south:forest_entrance,east:riverbank
ModifierFile:example-1.txt

Item:worn map
ItemDescription:An old, faded map showing a portion of the surrounding area. It seems to indicate something valuable is hidden nearby.
```
The ModifierFile option is a very powerful tool. It enables you to load another config file when the player successfully enters a location. The contents of that config file are overlayed on
the current config. You can add or change all configurable objects. If you change an object, the properties of that object will reflect the values in the modifier file.
The only exception is for items in a room. Those are added to the items that are already present in the room. This is because players can drop items in a room and you don't want those items to disappear.

Example of a modifier for the config above:
```
RoomID:forest_entrance
Items:pine cone
Persons:recluse
Exits:north:clearing,east:path,west:village,east:cabin

Item:pine cone
ItemDescription:A normal pine cone

Person:recluse
DisplayName:Recluse
Keywords:cabin:cabin key
NegativeAskResponse:I don't know anything about that.
```

The location forest_entrance will now have a pine cone added as an item and a recluse will be available for questions.

## Final Destination
FinalDestination: (exactly one required)

```
FinalDestination:<RoomID of winning location>
```


## Hint Configuration
Provide optional hints players can request.

```
Hint:<subject>:<hint text>
```

Example:
```
Hint:locked chest:Try examining your surroundings for clues about what might open it.
```

### Best Practices
- Use descriptive names for items, persons, and rooms
- Plan a clear objective that guides the player
- Include multiple paths or solutions when possible
- Test frequently using debug mode to catch errors early
- Balance difficulty with helpful hints
- Ensure there are no "unwinnable" states where the player can get stuck

By following these guidelines, you'll be able to create engaging and replayable adventure games!
