from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="SAGI_",
        env_file=".env",
        extra="ignore",
    )

    model: str = "yolo11n.pt"
    device: str = "cpu"
    analysis_fps: float = 3.0
    conf: float = 0.25
    imgsz: int = 416
    max_upload_mb: int = 4096
    data_dir: Path = Path("./data")


settings = Settings()
settings.data_dir.mkdir(parents=True, exist_ok=True)
