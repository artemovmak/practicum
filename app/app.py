import os
import logging
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__)


APP_PORT = int(os.environ.get('APP_PORT', 5000))
LOG_LEVEL_STR = os.environ.get('LOG_LEVEL', 'INFO').upper()
GREETING_HEADER = os.environ.get('GREETING_HEADER', 'Welcome to the custom app')
LOG_DIR = '/app/logs'
LOG_FILE = os.path.join(LOG_DIR, 'app.log')

config_dir = '/app/config'
try:
    with open(os.path.join(config_dir, 'APP_PORT'), 'r') as f:
        APP_PORT = int(f.read().strip())
except FileNotFoundError:
    pass

try:
    with open(os.path.join(config_dir, 'LOG_LEVEL'), 'r') as f:
        LOG_LEVEL_STR = f.read().strip().upper()
except FileNotFoundError:
    pass

try:
    with open(os.path.join(config_dir, 'GREETING_HEADER'), 'r') as f:
        GREETING_HEADER = f.read().strip()
except FileNotFoundError:
    pass


os.makedirs(LOG_DIR, exist_ok=True)
log_level = getattr(logging, LOG_LEVEL_STR, logging.INFO)

file_handler = logging.FileHandler(LOG_FILE)
file_handler.setLevel(log_level)
file_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(file_formatter)

stream_handler = logging.StreamHandler()
stream_handler.setLevel(log_level)
stream_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
stream_handler.setFormatter(stream_formatter)

logging.basicConfig(level=log_level, handlers=[file_handler, stream_handler])

logging.info(f"App starting on port {APP_PORT} with log level {LOG_LEVEL_STR}")
logging.info(f"Greeting header set to: '{GREETING_HEADER}'")
logging.info(f"Logging to file: {LOG_FILE}")


@app.route('/')
def index():
    logging.info(f"Received request for / from {request.remote_addr}")
    return GREETING_HEADER

@app.route('/status')
def status():
    logging.debug(f"Received request for /status from {request.remote_addr}")
    return jsonify({"status": "ok"})

@app.route('/log', methods=['POST'])
def log_message():
    try:
        data = request.get_json()
        if not data or 'message' not in data:
            logging.warning(f"Invalid log request from {request.remote_addr}: Missing 'message' key")
            return jsonify({"error": "Missing 'message' key in JSON payload"}), 400

        message = data['message']
        logging.info(f"API_LOG: {message}")
        return jsonify({"status": "logged", "message": message}), 201
    except Exception as e:
        logging.error(f"Error processing /log request from {request.remote_addr}: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500

@app.route('/logs')
def get_logs():
    logging.debug(f"Received request for /logs from {request.remote_addr}")
    try:
        return send_from_directory(LOG_DIR, 'app.log', as_attachment=False)
    except FileNotFoundError:
        logging.warning(f"Log file {LOG_FILE} not found when requested by {request.remote_addr}")
        return "Log file not found.", 404
    except Exception as e:
        logging.error(f"Error serving log file: {e}", exc_info=True)
        return "Error reading log file.", 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=APP_PORT, debug=(LOG_LEVEL_STR == 'DEBUG'))
