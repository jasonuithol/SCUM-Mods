import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel

import bot as botmod
from config import settings
from map_render import render_ping

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("sidecar")


def _on_bot_task_done(task: asyncio.Task) -> None:
    # The bot runs as a fire-and-forget task, so without this callback any exception
    # raised during startup (bad token, bot not in the configured guild, failed slash
    # sync, etc.) would be swallowed and only show up as a permanent discord_ready=false.
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        log.error("Discord bot stopped with an error: %s", exc, exc_info=exc)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Run the Discord Gateway connection as a background task on uvicorn's event loop.
    task = asyncio.create_task(botmod.bot.start(settings.discord_bot_token))
    task.add_done_callback(_on_bot_task_done)
    log.info("Discord bot starting...")
    try:
        yield
    finally:
        log.info("Shutting down Discord bot...")
        await botmod.bot.close()
        task.cancel()


app = FastAPI(title="SCUM Discord Sidecar", lifespan=lifespan)


def require_api_key(x_api_key: str = Header(default="")) -> None:
    if x_api_key != settings.sidecar_api_key:
        raise HTTPException(status_code=401, detail="invalid API key")


class GameEvent(BaseModel):
    type: str          # e.g. "join", "death", "chat", "status"
    message: str


@app.get("/health")
async def health():
    return {"ok": True, "discord_ready": botmod.bot.is_ready()}


@app.post("/event", dependencies=[Depends(require_api_key)])
async def post_event(event: GameEvent):
    """Called by the UE4SS mod to relay an in-game event into Discord."""
    if not botmod.bot.is_ready():
        raise HTTPException(status_code=503, detail="Discord not connected yet")
    await botmod.send_to_channel(f"**[{event.type}]** {event.message}")
    return {"sent": True}


class MapPing(BaseModel):
    player: str
    x: float
    y: float


@app.post("/ping", dependencies=[Depends(require_api_key)])
async def post_ping(ping: MapPing):
    """Called by the mod when a player types 'ping' in-game.

    Renders the player's position on the map and posts it to the channel.
    """
    if not botmod.bot.is_ready():
        raise HTTPException(status_code=503, detail="Discord not connected yet")
    image = render_ping(ping.player, ping.x, ping.y)
    await botmod.send_ping(ping.player, ping.x, ping.y, image)
    return {"sent": True}


@app.get("/commands", dependencies=[Depends(require_api_key)])
async def get_commands():
    """Polled by the UE4SS mod to pull commands issued from Discord (slash/buttons)."""
    return {"commands": botmod.drain_game_commands()}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=settings.host, port=settings.port)
