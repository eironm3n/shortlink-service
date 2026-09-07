from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, overridable via SHORTLINK_* env vars or a .env file."""

    model_config = SettingsConfigDict(env_prefix="SHORTLINK_", env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./shortlink.db"
    base_url: str = "http://localhost:8000"
    code_length: int = 7
    version: str = "dev"


@lru_cache
def get_settings() -> Settings:
    return Settings()
