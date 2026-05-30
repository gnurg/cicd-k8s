from flask import Flask
import socket
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)


@app.route("/")
def hello_world():
    html = f"<body style='background-color:{os.environ.get('BG_COLOR')};'>\
    <h1 style='color:{os.environ.get('FONT_COLOR')}'>{os.environ.get('CUSTOM_HEADER')}</h1> \
    <p>Env: {os.environ.get('FLASK_ENV')}</p> \
    <img src='{os.environ.get('CUSTOM_PHOTO')}' alt='CUSTOMER_PHOTO'>\
    <h2 style='color:{os.environ.get('FONT_COLOR')};'>Hello World! Served from <b>{socket.gethostname()}</b></h2></body>"
    return html


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
