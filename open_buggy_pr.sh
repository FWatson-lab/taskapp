#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# open_buggy_pr.sh
#
# Prerequisites:
#   - You're inside the taskapp/ git repo with a remote set up
#   - gh (GitHub CLI) is installed and authenticated
#   - The main branch is already pushed
#
# What it does:
#   1. Creates a feature branch
#   2. Writes buggy files directly (no patches needed)
#   3. Commits and pushes
#   4. Opens a real PR via `gh pr create`
#
# Usage:
#   cd taskapp
#   bash open_buggy_pr.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

BRANCH="feature/bulk-operations"

# Bail if not in a git repo
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || {
  echo "ERROR: Not inside a git repository. cd into taskapp/ first."
  exit 1
}

# Bail if gh is missing
command -v gh > /dev/null 2>&1 || {
  echo "ERROR: gh (GitHub CLI) is not installed."
  echo "Install it: https://cli.github.com/"
  exit 1
}

# Make sure we're on main and clean
git checkout main 2>/dev/null || git checkout -b main
git diff --quiet && git diff --cached --quiet || {
  echo "ERROR: Working tree is dirty. Commit or stash first."
  exit 1
}

# Delete the branch locally if it already exists
git branch -D "$BRANCH" 2>/dev/null || true
git push origin --delete "$BRANCH" 2>/dev/null || true

echo "==> Creating branch: $BRANCH"
git checkout -b "$BRANCH"

# ─────────────────────────────────────────────────────────────
# Write buggy files
# ─────────────────────────────────────────────────────────────

# ── backend/app.py — append bulk endpoints with bugs ──
cat >> backend/app.py << 'PYEOF'


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
PYEOF

# ── backend/auth.py — wrong header ──
cat > backend/auth.py << 'PYEOF'
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
PYEOF

# ── backend/config.py — bool("0") is True ──
cat > backend/config.py << 'PYEOF'
"""Application configuration loaded from environment variables."""
import os


class Config:
    DATABASE = os.environ.get("TASKAPP_DB", "tasks.db")
    API_KEY = os.environ.get("TASKAPP_API_KEY", "dev-key-change-me")
    DEBUG = bool(os.environ.get("TASKAPP_DEBUG", "0"))
PYEOF

# ── frontend/app.js — race condition, no await ──
cat > frontend/app.js << 'JSEOF'
const API_BASE = "http://localhost:5000/api";

const $  = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

const apiKeyInput = $("#api-key");
const filterSelect = $("#filter");
const list = $("#task-list");
const form = $("#new-task-form");

apiKeyInput.value = localStorage.getItem("taskapp_key") || "";
apiKeyInput.addEventListener("change", () => {
  localStorage.setItem("taskapp_key", apiKeyInput.value);
});

function headers() {
  return {
    "Content-Type": "application/json",
    "X-API-Key": apiKeyInput.value,
  };
}

async function fetchTasks() {
  const status = filterSelect.value;
  const url = status ? `${API_BASE}/tasks?status=${status}` : `${API_BASE}/tasks`;
  const res = await fetch(url, { headers: headers() });
  if (!res.ok) {
    list.innerHTML = `<li>Error: ${res.status}</li>`;
    return;
  }
  const tasks = await res.json();
  render(tasks);
}

function render(tasks) {
  list.innerHTML = "";
  for (const t of tasks) {
    const li = document.createElement("li");
    li.className = `task ${t.status}`;
    li.innerHTML = `
      <input type="checkbox" ${t.status === "done" ? "checked" : ""} data-id="${t.id}" class="toggle">
      <div>
        <div class="title">${escape(t.title)}</div>
        ${t.description ? `<div class="desc">${escape(t.description)}</div>` : ""}
      </div>
      <div class="meta">
        <span class="badge ${t.priority}">${t.priority}</span>
        <button class="btn-delete" data-id="${t.id}">Delete</button>
        <button class="btn-bulk" data-id="${t.id}">Select</button>
      </div>
    `;
    list.appendChild(li);
  }
}

function escape(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}

function bulkDelete() {
  const selected = [...$$(".btn-bulk.selected")].map(b => b.dataset.id);
  if (!selected.length) return;
  fetch(`${API_BASE}/tasks/bulk-delete`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ ids: selected }),
  });
  fetchTasks();
}

list.addEventListener("click", async (e) => {
  const id = e.target.dataset.id;
  if (!id) return;
  if (e.target.classList.contains("btn-bulk")) {
    e.target.classList.toggle("selected");
    return;
  }
  if (e.target.classList.contains("btn-delete")) {
    await fetch(`${API_BASE}/tasks/${id}`, { method: "DELETE", headers: headers() });
    fetchTasks();
  } else if (e.target.classList.contains("toggle")) {
    const newStatus = e.target.checked ? "done" : "open";
    await fetch(`${API_BASE}/tasks/${id}`, {
      method: "PATCH",
      headers: headers(),
      body: JSON.stringify({ status: newStatus }),
    });
    fetchTasks();
  }
});

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(form);
  const body = Object.fromEntries(fd.entries());
  await fetch(`${API_BASE}/tasks`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(body),
  });
  form.reset();
  fetchTasks();
});

$("#refresh").addEventListener("click", fetchTasks);
filterSelect.addEventListener("change", fetchTasks);

fetchTasks();
JSEOF

# ── scripts/seed.py — swapped columns ──
cat > scripts/seed.py << 'PYEOF'
#!/usr/bin/env python3
"""Seed the database with a handful of sample tasks for local dev."""
import sqlite3
import os
from datetime import datetime

DB = os.environ.get("TASKAPP_DB", "tasks.db")

SAMPLES = [
    ("Write design doc", "Draft the v2 architecture doc", "high", "open"),
    ("Fix login bug", "Users report 500 on password reset", "high", "in_progress"),
    ("Upgrade deps", "Bump Flask to 3.x", "low", "open"),
    ("Add dark mode", "Frontend theme toggle", "medium", "done"),
    ("Write onboarding email", "For new signups", "medium", "cancelled"),
]


def main():
    conn = sqlite3.connect(DB)
    now = datetime.utcnow().isoformat()
    for title, desc, prio, status in SAMPLES:
        conn.execute(
            "INSERT INTO tasks (title, description, priority, status, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (title, prio, desc, status, now),
        )
    conn.commit()
    conn.close()
    print(f"Seeded {len(SAMPLES)} tasks into {DB}")


if __name__ == "__main__":
    main()
PYEOF

# ── Dockerfile — wrong EXPOSE port ──
cat > Dockerfile << 'DEOF'
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends sqlite3 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/   ./backend/
COPY migrations/ ./migrations/
COPY scripts/   ./scripts/

RUN chmod +x scripts/init_db.sh && ./scripts/init_db.sh

ENV TASKAPP_DB=/app/tasks.db
ENV TASKAPP_API_KEY=change-me-in-production

EXPOSE 8080
CMD ["python", "-m", "backend.app"]
DEOF

# ─────────────────────────────────────────────────────────────
# Commit, push, open PR
# ─────────────────────────────────────────────────────────────

echo "==> Committing buggy changes..."
git add -A
git commit -m "feat: add bulk operations endpoints

- Add POST /api/tasks/bulk-delete for batch deletion
- Add POST /api/tasks/bulk-update for batch status changes
- Add bulk select UI to frontend
- Update seed script and config" --quiet

echo "==> Pushing branch..."
git push -u origin "$BRANCH"

echo "==> Opening PR via gh..."
gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "feat: add bulk operations endpoints" \
  --body "## Summary

Adds two new bulk-operation endpoints and corresponding frontend UI:

- \`POST /api/tasks/bulk-delete\` — delete multiple tasks by ID
- \`POST /api/tasks/bulk-update\` — change status of multiple tasks at once
- Frontend \"Select\" buttons for bulk actions
- Minor config and seed script cleanup

## Changes

| File | What changed |
|------|-------------|
| \`backend/app.py\` | Added bulk_delete and bulk_update routes |
| \`backend/auth.py\` | Refactored header reading |
| \`backend/config.py\` | Simplified DEBUG flag parsing |
| \`frontend/app.js\` | Added bulk select/delete UI |
| \`scripts/seed.py\` | Cleaned up insert statement |
| \`Dockerfile\` | Updated port config |

## Testing

- [ ] Existing tests still pass
- [ ] New endpoints tested manually
- [ ] Frontend works end to end"

echo ""
echo "==> PR created! You can view it with:"
echo ""
echo "    gh pr view --web"
echo ""
