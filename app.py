from flask import Flask, render_template, jsonify
import subprocess

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/play', methods=['POST'])
def play_game():
    try:
        # Run the Perl script and capture its output
        result = subprocess.run(['perl', 'adventure_game.pl'], capture_output=True, text=True)
        return jsonify({'output': result.stdout})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)
