# Task Manager

A tiny full-stack task manager. Useful for practicing CLI workflows across a
mixed-language codebase.

## Stack

- **Backend:** Python 3.12 + Flask + SQLite
- **Frontend:** vanilla HTML/CSS/JS
- **Infra:** Bash migration runner, Dockerfile, Makefile
- **Tests:** pytest

## Layout

```
taskapp/
├── backend/         # Flask app (app.py, auth.py, config.py)
├── frontend/        # Static index.html + app.js + styles.css
├── migrations/      # Raw .sql files applied in order
├── scripts/         # init_db.sh, seed.py
├── tests/           # pytest suite
├── docs/            # API reference
├── Dockerfile
├── Makefile
└── requirements.txt
```

## Quickstart

```bash
make install
make init        # create tasks.db from migrations
make seed        # optional sample data
make run         # http://localhost:5000
```

Open `frontend/index.html` in a browser and paste the API key
(default `dev-key-change-me`).

## Environment variables

| Var                | Default             | Purpose                         |
|--------------------|---------------------|---------------------------------|
| `TASKAPP_DB`       | `tasks.db`          | SQLite file path                |
| `TASKAPP_API_KEY`  | `dev-key-change-me` | Required on every `/api/*` call |
| `TASKAPP_DEBUG`    | `0`                 | Set to `1` for Flask debug mode |

## Tests

```bash
make test
```

## Docker

```bash
make docker
```

See `docs/API.md` for the full endpoint reference.
