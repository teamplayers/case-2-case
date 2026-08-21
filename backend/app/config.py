from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(ROOT / ".env"),
        extra="ignore",
    )

    mongodb_uri: str = "mongodb://127.0.0.1:27017"
    mongodb_db: str = "case2case"
    jwt_secret: str = "change-me-in-production"
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    whisper_model: str = "large-v3"
    data_dir: str = str(ROOT / "data")
    cors_origins: str = "http://127.0.0.1:8080,http://localhost:8080"

    @property
    def origins(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def data_path(self) -> Path:
        return Path(self.data_dir).resolve()


settings = Settings()
