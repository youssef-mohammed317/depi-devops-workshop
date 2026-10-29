from flask import Flask, jsonify

app = Flask(__name__)


homeDictionary = {
    "message": "Welcome to the Flask application!",
    "status": "success"
}

healthDictionary = {
    "status": "healthy",
    "service": "flask-app"
}

@app.route('/')
def home():
    return jsonify(homeDictionary), 200


@app.route("/health")
def health():
    return jsonify(healthDictionary), 200


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)