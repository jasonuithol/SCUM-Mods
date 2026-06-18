from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Discord
    discord_bot_token: str
    discord_channel_id: int
    # Optional: set this to your server's guild ID for instant slash-command sync.
    # Leave unset for a global sync (can take up to an hour to appear).
    discord_guild_id: int | None = None

    # Local API shared by the UE4SS mod and this sidecar.
    sidecar_api_key: str = "change-me"
    host: str = "127.0.0.1"
    port: int = 8765

    # Map rendering. Provide your own SCUM map image at this path.
    map_image_path: str = "scum_map.png"

    # World-to-map calibration. These map in-game world coordinates (Unreal units, cm)
    # onto the image's pixels. THE DEFAULTS ARE PLACEHOLDERS — calibrate them by noting
    # the world coords at two known points on your map image and solving for the bounds.
    # Calibrated 2026-06-18 from two in-game pings (image 1284x1276):
    #   world (-634648, 416571) -> px (1054, 164)
    #   world ( 138139,-213358) -> px ( 401, 692)
    # X axis is intentionally inverted (min > max): negative world X is map-right.
    world_min_x: float = 612703.0
    world_max_x: float = -906836.0
    world_min_y: float = -910096.0
    world_max_y: float = 612231.0


settings = Settings()
