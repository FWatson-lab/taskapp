FROM python:3.12-slim

WORKDIR /app

# Install sqlite3 for the init script
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

EXPOSE 5000
CMD ["python", "-m", "backend.app"]
