from flask import Flask, jsonify
from werkzeug.exceptions import HTTPException

from app.routes import bp


def create_app() -> Flask:
    app = Flask(__name__)
    app.register_blueprint(bp)

    @app.errorhandler(HTTPException)
    def handle_http_error(exc: HTTPException):
        return jsonify({"error": exc.name, "status": exc.code}), exc.code or 500

    @app.errorhandler(Exception)
    def handle_unhandled_error(_exc: Exception):
        return jsonify({"error": "internal server error", "status": 500}), 500

    return app


if __name__ == "__main__":
    create_app().run(host="0.0.0.0", port=5000)
