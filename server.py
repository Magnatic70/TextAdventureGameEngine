from flask import Flask, render_template, request, jsonify

app = Flask(__name__)

# Load game data from a file or define it here
game_data = {
    "title": "The Haunted Mansion",
    "first_room_id": "Entrance",
    "final_destination": "Cellar",
    # Add other necessary game data here...
}

current_room_id = game_data["first_room_id"]
inventory = []
room_history = []

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/move', methods=['POST'])
def move():
    global current_room_id
    action = request.json.get('action')
    room_data = game_data['rooms'].get(current_room_id, {})
    
    if action in room_data.get('exits', {}):
        next_room_id = room_data['exits'][action]
        room_history.append(current_room_id)
        current_room_id = next_room_id
        return jsonify(success=True, message="Moved successfully.")
    
    return jsonify(success=False, message="Invalid move.")

@app.route('/take', methods=['POST'])
def take():
    item = request.json.get('item')
    room_data = game_data['rooms'].get(current_room_id, {})
    
    if 'items' in room_data and item in room_data['items']:
        inventory.append(item)
        room_data['items'].remove(item)
        return jsonify(success=True, message=f"Took {item}.")
    
    return jsonify(success=False, message="Item not found.")

@app.route('/examine', methods=['POST'])
def examine():
    item = request.json.get('item')
    if item in inventory:
        # Provide description logic here
        return jsonify(success=True, message=f"Examined {item}.")
    
    return jsonify(success=False, message="Item not in inventory.")

# Add other endpoints for actions like search, combine, etc.

if __name__ == '__main__':
    app.run(debug=True)
