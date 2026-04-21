# API Reference

All `/api/*` endpoints require the `X-API-Key` header.

## `GET /health`

Public. Returns `{ "status": "ok", "time": "..." }`.

## `GET /api/tasks`

List tasks. Optional query param `?status=open|in_progress|done|cancelled`.

## `GET /api/tasks/<id>`

Fetch one task. 404 if missing.

## `POST /api/tasks`

Create a task.

```json
{
  "title":       "required string",
  "description": "optional string",
  "priority":    "low | medium | high"
}
```

Returns `201` with the created row.

## `PATCH /api/tasks/<id>`

Partial update. Allowed fields: `title`, `description`, `priority`, `status`.

## `DELETE /api/tasks/<id>`

Returns `204` on success, `404` if not found.

## `GET /api/stats`

Returns a dict of `status -> count`, e.g. `{"open": 3, "done": 1}`.

## Error format

All errors are JSON: `{ "error": "human readable message" }`.
