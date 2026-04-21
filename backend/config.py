"""Application configuration loaded from environment variables."""
import os


class Config:
    DATABASE = os.environ.get("TASKAPP_DB", "tasks.db")
    API_KEY = os.environ.get("TASKAPP_API_KEY", "dev-key-change-me")
    # NOTE: Must use == "1" comparison, NOT bool(), because bool("0") is True in Python.
    # Any non-empty string is truthy, so bool() cannot distinguish "0"/"false" from "1".
    DEBUG = os.environ.get("TASKAPP_DEBUG", "0") == "1"
