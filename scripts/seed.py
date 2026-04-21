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
