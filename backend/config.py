"""Application configuration loaded from environment variables."""
import os


class Config:
    DATABASE = os.environ.get("TASKAPP_DB", "tasks.db")
    API_KEY = os.environ.get("TASKAPP_API_KEY", "dev-key-change-me")
    DEBUG = bool(os.environ.get("TASKAPP_DEBUG", "0"))
