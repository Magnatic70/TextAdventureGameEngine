from flask import Flask, request, jsonify, render_template, send_from_directory
import os
import subprocess
import re
import configparser

app = Flask(__name__)

# Load games from config file
def load_games():
    config = configparser.ConfigParser()
    config.read('games.cfg')
    
    games = []
    for section in config.sections():
        if section != 'DEFAULT':
            game_name, _, _ = section.split(';')
            games.append(game_name)
    
    return games

# Get list of configured games
GAMES = load_games()

@app.route('/')
def home():
    return render_template('index.html', games=GAMES)

@app.route('/styles.css')
def styles():
    return send_from_directory(os.path.join(app.root_path, 'static'),'styles.css')

@app.route('/scripts.js')
def scripts():
    return send_from_directory(os.path.join(app.root_path, 'static'),'scripts.js')

@app.route('/favicon.png')
def favicon():
    return send_from_directory(os.path.join(app.root_path, 'static'),'favicon.png', mimetype='image/vnd.microsoft.icon')

@app.route('/send-action', methods=['POST'])
def send_action():
    data = request.get_json()
    game_name = data['gameName']
    session_id = data['sessionID']
    action = data['action']

    # Validate session ID format
    if not re.match(r'^[A-Za-z0-9]{32}$', session_id):
        return jsonify({'error': 'Invalid session ID format'}), 400

    # Create a temporary file for the game output
    output_file = f"{session_id}"
    
    # Call the Perl script with parameters
    result = subprocess.run(
        ['perl', 'adventure_game.pl', game_name, 'file', session_id, action],
    )
    
    # Read the output from file instead of STDOUT
    with open(output_file, 'r') as f:
        game_output = f.read()
    
    # Clean up temporary file
    os.remove(output_file)
    
    return jsonify(game_output)

if __name__ == '__main__':
    app.run(debug=True, port=4545, host='0.0.0.0')
