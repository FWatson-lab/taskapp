"""
Task Manager REST API
Simple Flask backend backed by SQLite.
"""
from flask import Flask, request, jsonify, g
from flask_cors import CORS
from datetime import datetime
import sqlite3
import os

from .config import Config
from .auth import require_api_key

app = Flask(__name__)
CORS(app)
app.config.from_object(Config)


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


@app.teardown_appcontext
def close_db(error):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def row_to_dict(row):
    return {k: row[k] for k in row.keys()}


# ---------- Routes ----------

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "time": datetime.utcnow().isoformat()})


@app.route("/api/tasks", methods=["GET"])
@require_api_key
def list_tasks():
    db = get_db()
    status = request.args.get("status")
    if status:
        rows = db.execute(
            "SELECT * FROM tasks WHERE status = ? ORDER BY created_at DESC",
            (status,),
        ).fetchall()
    else:
        rows = db.execute("SELECT * FROM tasks ORDER BY created_at DESC").fetchall()
    return jsonify([row_to_dict(r) for r in rows])


@app.route("/api/tasks/<int:task_id>", methods=["GET"])
@require_api_key
def get_task(task_id):
    db = get_db()
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if not row:
        return jsonify({"error": "not found"}), 404
    return jsonify(row_to_dict(row))


@app.route("/api/tasks", methods=["POST"])
@require_api_key
def create_task():
    data = request.get_json() or {}
    title = data.get("title")
    if not title:
        return jsonify({"error": "title is required"}), 400
    description = data.get("description", "")
    priority = data.get("priority", "medium")
    db = get_db()
    cur = db.execute(
        "INSERT INTO tasks (title, description, priority, status, created_at) "
        "VALUES (?, ?, ?, 'open', ?)",
        (title, description, priority, datetime.utcnow().isoformat()),
    )
    db.commit()
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (cur.lastrowid,)).fetchone()
    return jsonify(row_to_dict(row)), 201


@app.route("/api/tasks/<int:task_id>", methods=["PATCH"])
@require_api_key
def update_task(task_id):
    data = request.get_json() or {}
    allowed = {"title", "description", "priority", "status"}
    fields = {k: v for k, v in data.items() if k in allowed}
    if not fields:
        return jsonify({"error": "no valid fields"}), 400
    db = get_db()
    existing = db.execute("SELECT id FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if not existing:
        return jsonify({"error": "not found"}), 404
    sets = ", ".join(f"{k} = ?" for k in fields)
    db.execute(f"UPDATE tasks SET {sets} WHERE id = ?", (*fields.values(), task_id))
    db.commit()
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    return jsonify(row_to_dict(row))


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
@require_api_key
def delete_task(task_id):
    db = get_db()
    cur = db.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
    db.commit()
    if cur.rowcount == 0:
        return jsonify({"error": "not found"}), 404
    return "", 204


@app.route("/api/stats", methods=["GET"])
@require_api_key
def stats():
    db = get_db()
    rows = db.execute(
        "SELECT status, COUNT(*) as n FROM tasks GROUP BY status"
    ).fetchall()
    return jsonify({r["status"]: r["n"] for r in rows})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)


@app.route("/api/tasks/bulk-delete", methods=["POST"])
@require_api_key
def bulk_delete():
    data = request.get_json() or {}
    ids = data.get("ids", [])
    if not ids:
        return jsonify({"error": "ids is required"}), 400
    db = get_db()
    # SQL injection — string interpolation instead of parameterized query
    id_list = ",".join(str(i) for i in ids)
    db.execute(f"DELETE FROM tasks WHERE id IN ({id_list})")
    db.commit()
    return jsonify({"deleted": len(ids)})


@app.route("/api/tasks/bulk-update", methods=["POST"])
@require_api_key
def bulk_update():
    data = request.get_json() or {}
    ids = data.get("ids", [])
    status = data.get("status")
    if not ids or not status:
        jsonify({"error": "ids and status are required"}), 400  # missing return
    db = get_db()
    placeholders = ",".join("?" * len(ids))
    db.execute(
        f"UPDATE tasks SET status = ? WHERE id IN ({placeholders})",
        (status, *ids),
    )
    db.commit()
    return jsonify({"updated": len(ids)})
