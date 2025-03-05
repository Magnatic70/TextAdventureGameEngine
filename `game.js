// Load game data from a text file
async function loadGameData() {
    const response = await fetch('game_data.txt');
    return response.text();
}

let currentRoomId, inventory, roomHistory;

function parseGameData(gameData) {
    const lines = gameData.split('\n');
    let rooms = {};
    let items = {};
    let persons = {};

    let currentSection = null;
    let currentRoom = null;
    let currentItem = null;
    let currentPerson = null;

    lines.forEach(line => {
        if (line.startsWith('Title:')) {
            document.getElementById('title').textContent = line.split(':')[1].trim();
        } else if (line.startsWith('Objective:')) {
            document.getElementById('objective').textContent = line.split(':')[1].trim();
        }

        if (line.startsWith('[Marketplace]') || line.startsWith('[TownHall]')) {
            currentSection = line.slice(1, -1);
            rooms[currentSection] = {};
        } else if (line.startsWith('RoomID:')) {
            currentRoom = { items: [], persons: [] };
            rooms[currentSection][line.split(':')[1].trim()] = currentRoom;
        } else if (line.startsWith('Item:') || line.startsWith('Person:')) {
            currentItem = null;
            currentPerson = null;
        }

        if (currentRoom) {
            if (line.startsWith('Name:')) currentRoom.name = line.split(':')[1].trim();
            if (line.startsWith('Description:')) currentRoom.description = line.split(':')[1].trim();
            if (line.startsWith('Exits:')) currentRoom.exits = parseKeyValue(line, ',');
            if (line.startsWith('Items:')) currentRoom.items = line.split(':')[1].split(',').map(item => item.trim());
            if (line.startsWith('Persons:')) currentRoom.persons = line.split(':')[1].split(',').map(person => person.trim());

            if (line.startsWith('Item:')) {
                currentItem = { contains: [] };
                items[line.split(':')[1].trim()] = currentItem;
            }
            if (line.startsWith('Person:')) {
                currentPerson = {};
                persons[line.split(':')[1].trim()] = currentPerson;
            }

            if (currentItem) {
                if (line.startsWith('Contains:')) currentItem.contains = line.split(':')[1].split(',').map(item => item.trim());
                if (line.startsWith('ItemDescription:')) currentItem.description = line.split(':')[1].trim();
            }
            if (currentPerson) {
                if (line.startsWith('Keywords:')) currentPerson.keywords = parseKeyValue(line, ';');
                if (line.startsWith('Trades:')) currentPerson.trades = parseKeyValue(line, ';');
            }
        }

        function parseKeyValue(line, delimiter) {
            const keyValuePairs = line.split(':')[1].split(delimiter);
            const result = {};
            keyValuePairs.forEach(pair => {
                const [key, value] = pair.split(':').map(part => part.trim());
                result[key] = value;
            });
            return result;
        }
    });

    return { rooms, items, persons };
}

async function startGame() {
    const gameDataText = await loadGameData();
    const { rooms, items, persons } = parseGameData(gameDataText);

    currentRoomId = 'Marketplace';
    inventory = [];
    roomHistory = [];

    updateDisplay(rooms[currentRoomId]);
}

function updateDisplay(room) {
    document.getElementById('description').textContent = room.description;
    document.getElementById('exits').innerHTML = Object.entries(room.exits || {}).map(([direction, location]) => `<li>${direction}</li>`).join('');
    document.getElementById('items').innerHTML = room.items.map(item => `<li>${item}</li>`).join('');
    document.getElementById('persons').innerHTML = room.persons.map(person => `<li>${person}</li>`).join('');
}

function handleAction() {
    const actionInput = document.getElementById('action-input');
    const action = actionInput.value.trim();
    actionInput.value = '';

    // Handle actions like move, take, examine, etc.
    if (action.startsWith('move ')) {
        const direction = action.split(' ')[1];
        moveToRoom(direction);
    } else if (action.startsWith('take ')) {
        const item = action.split(' ')[1];
        takeItem(item);
    }
}

function moveToRoom(direction) {
    const currentRoom = gameData.rooms[currentSection][currentRoomId];
    const nextRoomId = currentRoom.exits[direction];

    if (nextRoomId) {
        roomHistory.push(currentRoomId);
        currentRoomId = nextRoomId;
        updateDisplay(gameData.rooms[currentSection][currentRoomId]);
    } else {
        alert('You can\'t go that way.');
    }
}

function takeItem(item) {
    const currentRoom = gameData.rooms[currentSection][currentRoomId];
    if (currentRoom.items.includes(item)) {
        inventory.push(item);
        currentRoom.items = currentRoom.items.filter(i => i !== item);
        alert(`You took the ${item}.`);
        updateDisplay(currentRoom);
    } else {
        alert('That item is not here.');
    }
}

startGame();
