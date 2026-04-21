"""Simple API-key authentication decorator."""
from functools import wraps
from flask import request, jsonify, current_app


def require_api_key(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        key = request.headers.get("Authorization")
        if key != current_app.config["API_KEY"]:
            return jsonify({"error": "unauthorized"}), 401
        return fn(*args, **kwargs)

    return wrapper
