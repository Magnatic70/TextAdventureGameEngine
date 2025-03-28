# Text Adventure Game Engine
The Adventure Game Engine (AGE) is a tool for creating classic text-based adventure games. You can create your own adventures by configuring them through simple text files, making it accessible without coding experience 
readme.txt

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
* Fight: fight [enemy] with [item]
* Retreat (during combat)
* Get hints: hint [subject]

# Game Modes
1. **Plain Perl Program**: Run directly from the command line: `./adventure_game.pl <game name>`
2. **Debug Mode**: Use for automated testing by piping test steps to the engine: `cat <test steps> | ./adventure_game.pl <game name>` (stops at unknown commands/items)
3. **Browser Frontend**: Run the backend and access through a web browser at `http://<your ip>:4545`
   - First start: `python3 app.py`
4. **Docker Container**: Create with `./build-docker.sh` and run with `./start-docker.sh`
   - You'll find the frontend in your web browser at `http://<your ip>:4546`

# Configuration
## Configuration Structure
Adventures are built using a configuration file that defines the game world. The main components are:
- Items
- Persons
- Rooms (Locations)
- Hints
- Final Destination
- Objective

## Objective
Defines the goal of the game, shown at the start. Format: `Objective:<text to brief the player on the adventure they are going to embark on>`

## Item Configuration
Items can be found by taking, receiving as gifts, trading, or through searching.

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
Person:<short person name>
Keywords:<topic>:<gift item>;<topic2>:<gift item2>;... (optional)
Trades:<player offered item>:<person gives item>:<response> (optional)
```

Example:
```
Person:Old Man Hemlock
Keywords:secret passage:map;treasure:gold coin
Trades:apple pie:small potion:Ah, you shouldn't have! But I appreciate the gesture.
```

## Room Configuration
Rooms define locations with descriptions and connections to other rooms.

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
RewardItem:<item given for correct answer> (mandatory if Puzzle is defined)
Enemy:<enemy name>:<required weapon> (optional, mutually exclusive with Puzzle)
DefeatDescription:<message when player wins fight> (mandatory if Enemy is defined)
DiedDescription:<message when player loses fight> (mandatory if Enemy is defined)
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

Item:worn map
ItemDescription:An old, faded map showing a portion of the surrounding area. It seems to indicate something valuable is hidden nearby.
```
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
