document.addEventListener('DOMContentLoaded', () => {
    const actionInput = document.getElementById('actionInput');
    actionInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault(); // Prevent the default form submission
            sendAction();
        }
    });

    // Set initial page title
    document.getElementById('pageTitle').textContent = 'Text based Adventure';

    fetch('games') // Create a new route in app.py to serve this
        .then(response => response.json())
        .then(data => {
            const gameSelect = document.getElementById('gameName');
            
            // Clear existing options
            gameSelect.innerHTML = '';
            
            // Add default option
            const defaultOption = document.createElement('option');
            defaultOption.value = '';
            defaultOption.text = 'Select a game...';
            defaultOption.disabled = true;
            gameSelect.appendChild(defaultOption);

            let firstGame=true;
            
            // Add options for each game
            data.forEach(game => {
                const option = document.createElement('option');
                option.value = game.shortName; // Use shortName as value (for backend)
                option.text = `${game.displayName}`;
                if(firstGame){
                    firstGame=false;
                    option.selected=true;
                    // Set initial page title to the selected game
                    document.getElementById('pageTitle').textContent = option.text;
                }
                gameSelect.appendChild(option);
            });
            
            // Enable controls after games are loaded
            document.getElementById('actionInput').disabled = false;
            const gameNameSelect = document.getElementById('gameName');
            const storedGame = localStorage.getItem('gameName');

            if (storedGame) {
                gameNameSelect.value = storedGame;
                // Update title when a game is selected from storage
                document.getElementById('pageTitle').textContent = gameSelect.options[gameSelect.selectedIndex].text;
            }
            
            // Initialize UI state
            showDebugControls = false;
            updateUI();

            const sessionID = localStorage.getItem('sessionID') || generateSessionID();
            document.getElementById('sessionID').value=sessionID;
            localStorage.setItem('sessionID', sessionID);
            sendAction();

        })
        .catch(error => {
            console.error('Error loading games:', error);
            alert('Failed to load available games.');
        });

});

document.getElementById('actionInput').focus();
document.getElementById('tc').style.width = document.getElementById('responseDiv').clientWidth+'px';
document.getElementById('tc').style.left = document.getElementById('responseDiv').style.left+'px';

// Toggle state for debug controls
function toggleDebugControls() {
    showDebugControls = !showDebugControls;
    updateUI();
}

// Update UI based on current state
function updateUI() {
    const debugContainer = document.querySelector('.debug-controls');
    if (debugContainer) {
        debugContainer.style.display = showDebugControls ? 'flex' : 'none';
    }
}

// All other functions remain the same
function setSessionID(){
    localStorage.setItem('sessionID', document.getElementById('sessionID').value);
    toggleDebugControls();
    sendAction();
}

function storeGame(){
    const selectedOption = document.getElementById('gameName');
    localStorage.setItem('gameName',selectedOption.value);
    toggleDebugControls();
    sendAction();
    // Update title when a new game is selected
    document.getElementById('pageTitle').textContent = selectedOption.options[selectedOption.selectedIndex].text;
}
    
function sendAction() {
    const gameName = document.getElementById('gameName').value;
    const action = document.getElementById('actionInput').value;
    const sessionID = localStorage.getItem('sessionID');

    document.body.style.cursor = 'wait';
    document.getElementById('actionInput').disabled=true;

    fetch('send-action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ gameName, sessionID, action })
    })
    .then(response => response.text())
    .then(data => {
        document.body.style.cursor = 'default';
        document.getElementById('actionInput').disabled=false;
        
        const decodedData = decodeANSItoHTML(data);
        document.getElementById('response').innerHTML=decodedData;
        document.getElementById('responseDiv').scrollTo(0, document.getElementById('responseDiv').scrollHeight);
        document.getElementById('actionInput').value='';
        document.getElementById('actionInput').focus();
    });
}

function generateSessionID() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < 32; i++) {
        result += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    return result;
}

function generateNewSessionID() {
    const newSessionID = generateSessionID();
    document.getElementById('sessionID').value=newSessionID;
    localStorage.setItem('sessionID', document.getElementById('sessionID').value);
    toggleDebugControls();
    sendAction();
}

function decodeANSItoHTML(ansiString) {
    ansiString=ansiString.replaceAll(/\\n/g,'<br>');
    ansiString=ansiString.replaceAll(/\\"/g,'##');
    ansiString=ansiString.replaceAll(/"/g,'');
    ansiString=ansiString.replaceAll(/##/g,'"');
    ansiString=ansiString.replaceAll(/\\u001b\[97;1;4m/g,'<u>');
    ansiString=ansiString.replaceAll(/\\u001b\[0m/g,'</u></font></b>');
    ansiString=ansiString.replaceAll(/\\u001b\[47m\\u001b\[30m/g,'<font color="White" style="background-color: black">');
    ansiString=ansiString.replaceAll(/\\u001b\[32m/g,'<font color="Green">');
    ansiString=ansiString.replaceAll(/\\u001b\[36m/g,'<font color="DarkTurquoise">');
    ansiString=ansiString.replaceAll(/\\u001b\[93m/g,'<font color="Orange">');
    ansiString=ansiString.replaceAll(/\\u001b\[31m/g,'<font color="Red">');
    ansiString=ansiString.replaceAll(/\\u001b\[92m/g,'<font color="Lime">');
    ansiString=ansiString.replaceAll(/\\u001b\[34m/g,'<font color="Blue">');
    ansiString=ansiString.replaceAll(/\\u001b\[1m/g,'<b>');
    
    ansiString=ansiString.replaceAll(/\\u001b\[92;6m/g,'<font color="Red" style="font-size:24pt;background-color: yellow">');
    return ansiString;
}
