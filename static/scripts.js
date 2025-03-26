document.addEventListener('DOMContentLoaded', () => {
    const gameNameSelect = document.getElementById('gameName');
    const storedGame = localStorage.getItem('gameName');

    if (storedGame) {
        gameNameSelect.value = storedGame;
    }
    

    const sessionID = localStorage.getItem('sessionID') || generateSessionID();
    document.getElementById('sessionID').value=sessionID;
    localStorage.setItem('sessionID', sessionID);
    sendAction();

    const actionInput = document.getElementById('actionInput');
    actionInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault(); // Prevent the default form submission
            sendAction();
        }
    });
});

document.getElementById('actionInput').focus();

function setSessionID(){
    localStorage.setItem('sessionID', document.getElementById('sessionID').value);
}

function storeGame(){
    localStorage.setItem('gameName',document.getElementById('gameName').value);
    sendAction();
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
        document.getElementById('response').innerHTML=decodedData+"<br><br><br>";
        document.getElementById('response').scrollTo(0, document.getElementById('response').scrollHeight);
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
