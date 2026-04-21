"""Tests for the task API."""
import os
import tempfile
import pytest
import sqlite3

# Point DB to a temp file before importing the app
_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
_tmp.close()
os.environ["TASKAPP_DB"] = _tmp.name
os.environ["TASKAPP_API_KEY"] = "test-key"

# Initialize schema
with open(os.path.join(os.path.dirname(__file__), "..", "migrations", "001_init.sql")) as f:
    conn = sqlite3.connect(_tmp.name)
    conn.executescript(f.read())
    conn.close()

from backend.app import app  # noqa: E402

HEADERS = {"X-API-Key": "test-key"}


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_auth_required(client):
    r = client.get("/api/tasks")
    assert r.status_code == 401


def test_create_and_list(client):
    r = client.post("/api/tasks", json={"title": "Buy milk"}, headers=HEADERS)
    assert r.status_code == 201
    tid = r.get_json()["id"]

    r = client.get("/api/tasks", headers=HEADERS)
    assert r.status_code == 200
    titles = [t["title"] for t in r.get_json()]
    assert "Buy milk" in titles

    r = client.get(f"/api/tasks/{tid}", headers=HEADERS)
    assert r.get_json()["title"] == "Buy milk"


def test_missing_title(client):
    r = client.post("/api/tasks", json={}, headers=HEADERS)
    assert r.status_code == 400


def test_update(client):
    r = client.post("/api/tasks", json={"title": "Temp"}, headers=HEADERS)
    tid = r.get_json()["id"]
    r = client.patch(f"/api/tasks/{tid}", json={"status": "done"}, headers=HEADERS)
    assert r.get_json()["status"] == "done"


def test_delete(client):
    r = client.post("/api/tasks", json={"title": "Doomed"}, headers=HEADERS)
    tid = r.get_json()["id"]
    r = client.delete(f"/api/tasks/{tid}", headers=HEADERS)
    assert r.status_code == 204
    r = client.get(f"/api/tasks/{tid}", headers=HEADERS)
    assert r.status_code == 404


def test_stats(client):
    r = client.get("/api/stats", headers=HEADERS)
    assert r.status_code == 200
    assert isinstance(r.get_json(), dict)
