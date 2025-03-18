from flask import Flask, request, jsonify, render_template, send_from_directory
import os
import subprocess
import re

app = Flask(__name__)

@app.route('/')
def home():
    return render_template('index.html')

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

    # Call the Perl script with parameters
    result = subprocess.run(
        ['perl', 'adventure_game.pl', game_name, 'file', session_id, action],
        capture_output=True,
        text=True
    )
    print(result.stderr)
    return jsonify(result.stdout)

if __name__ == '__main__':
    app.run(debug=True, port=4546, host='0.0.0.0')
