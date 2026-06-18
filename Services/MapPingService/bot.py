import io
import logging
from collections import deque

import discord
from discord import app_commands
from discord.ext import commands

from config import settings

log = logging.getLogger("sidecar.bot")

# Commands destined for the game server. The UE4SS mod drains these via GET /commands.
# A deque is fine here: everything runs on the single shared asyncio loop, so there is
# no cross-thread access to guard against.
_command_queue: "deque[dict]" = deque()


def queue_game_command(command: dict) -> None:
    _command_queue.append(command)


def drain_game_commands() -> list[dict]:
    items = list(_command_queue)
    _command_queue.clear()
    return items


intents = discord.Intents.default()
# Slash commands and buttons do NOT need the privileged message_content intent.
# Only enable it (and toggle it in the Developer Portal) if you read normal chat text.


class SidecarBot(commands.Bot):
    def __init__(self) -> None:
        super().__init__(command_prefix="!", intents=intents)

    async def setup_hook(self) -> None:
        # Register the persistent view so its buttons keep working after a restart.
        self.add_view(ControlsView())

        # Sync slash commands. Guild-scoped sync is instant; global sync is slow to propagate.
        try:
            if settings.discord_guild_id:
                guild = discord.Object(id=settings.discord_guild_id)
                self.tree.copy_global_to(guild=guild)
                await self.tree.sync(guild=guild)
            else:
                await self.tree.sync()
        except discord.Forbidden as e:
            # Permissions bitfield: View Channels + Send Messages + Embed Links + Attach Files.
            invite_perms = 52224
            invite_url = (
                f"https://discord.com/api/oauth2/authorize?client_id={self.application_id}"
                f"&permissions={invite_perms}&scope=bot+applications.commands"
            )
            raise RuntimeError(
                f"Slash-command sync was forbidden (403). The bot is almost certainly "
                f"not a member of guild {settings.discord_guild_id}. Invite it (with the "
                f"'bot' and 'applications.commands' scopes) by opening this link in a "
                f"browser where you're logged into Discord, then restart:\n  {invite_url}\n"
                f"(If DISCORD_GUILD_ID is wrong, fix it in .env instead.)"
            ) from e


bot = SidecarBot()


@bot.event
async def on_ready() -> None:
    log.info("Discord bot connected as %s", bot.user)


async def _channel():
    channel = bot.get_channel(settings.discord_channel_id)
    if channel is None:
        channel = await bot.fetch_channel(settings.discord_channel_id)
    return channel


async def send_to_channel(content: str, *, view: discord.ui.View | None = None) -> None:
    await (await _channel()).send(content, view=view)


# Ping palette: (color key sent to the mod, button emoji, label, button style).
# The color key MUST match a key in the mod's MP.palette (pingback.lua). Discord
# buttons only have 5 fixed styles, so non-green/red colors are grey (secondary)
# and rely on the emoji square to convey the actual color.
PING_COLORS = [
    ("green",  "🟢", "Green",    discord.ButtonStyle.success),
    ("red",    "🔴", "Red",      discord.ButtonStyle.danger),
    ("pink",   "🩷", "Hot Pink", discord.ButtonStyle.secondary),
    ("yellow", "🟡", "Yellow",   discord.ButtonStyle.secondary),
    ("cyan",   "🩵", "Cyan",     discord.ButtonStyle.secondary),
    ("orange", "🟠", "Orange",   discord.ButtonStyle.secondary),
    ("violet", "🟣", "Violet",   discord.ButtonStyle.secondary),
    ("white",  "⚪", "White",    discord.ButtonStyle.secondary),
]


class _PingColorButton(discord.ui.Button):
    def __init__(self, color: str, emoji: str, label: str, style: discord.ButtonStyle, row: int) -> None:
        super().__init__(label=label, emoji=emoji, style=style, row=row)
        self.color = color

    async def callback(self, interaction: discord.Interaction) -> None:
        await self.view._queue(interaction, self.color)


class PingButtons(discord.ui.View):
    """Buttons posted under a map ping. Clicking one queues a 'map_ping' command
    that the UE4SS mod polls (GET /commands) and broadcasts back in-game as a
    colored circle on every player's map.

    This is a per-message (non-persistent) view: it carries the ping's x/y in the
    instance, so the buttons stop working after a sidecar restart. That's fine for
    ephemeral pings; persistence would mean encoding x/y into the custom_id.
    """

    def __init__(self, player: str, x: float, y: float) -> None:
        super().__init__(timeout=None)
        self.player = player
        self.x = x
        self.y = y
        # 8 buttons -> two rows of 4 (Discord allows max 5 per row, 5 rows).
        for i, (color, emoji, label, style) in enumerate(PING_COLORS):
            self.add_item(_PingColorButton(color, emoji, label, style, row=i // 4))

    async def _queue(self, interaction: discord.Interaction, color: str) -> None:
        queue_game_command(
            {
                "action": "map_ping",
                "x": self.x,
                "y": self.y,
                "color": color,
                "player": self.player,
                "by": str(interaction.user),
            }
        )
        await interaction.response.send_message(
            f"📍 {color.capitalize()} ping sent in-game at X:{self.x:.0f} Y:{self.y:.0f}",
            ephemeral=True,
        )


async def send_ping(player: str, x: float, y: float, image_png: bytes) -> None:
    file = discord.File(io.BytesIO(image_png), filename="ping.png")
    embed = discord.Embed(title="📍 Map Ping", description=f"**{player}** pinged a location")
    embed.add_field(name="Coordinates", value=f"X: {x:.0f}   Y: {y:.0f}")
    embed.set_image(url="attachment://ping.png")
    await (await _channel()).send(embed=embed, file=file, view=PingButtons(player, x, y))


# --- Discord -> game: slash commands and buttons enqueue work for the mod ---


@bot.tree.command(description="Broadcast a message to all players in-game")
@app_commands.describe(message="Text to show in-game")
async def broadcast(interaction: discord.Interaction, message: str) -> None:
    queue_game_command({"action": "broadcast", "message": message, "by": str(interaction.user)})
    await interaction.response.send_message(f"Queued broadcast: {message!r}", ephemeral=True)


class ControlsView(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=None)  # persistent

    @discord.ui.button(
        label="Announce restart",
        style=discord.ButtonStyle.danger,
        custom_id="sidecar:restart_warn",
    )
    async def restart_warn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        queue_game_command(
            {"action": "broadcast", "message": "Server restart in 5 minutes!", "by": str(interaction.user)}
        )
        await interaction.response.send_message("Queued restart warning.", ephemeral=True)

    @discord.ui.button(
        label="Ping players",
        style=discord.ButtonStyle.primary,
        custom_id="sidecar:ping",
    )
    async def ping(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        queue_game_command({"action": "ping", "by": str(interaction.user)})
        await interaction.response.send_message("Queued ping.", ephemeral=True)


@bot.tree.command(description="Post the server control panel with buttons")
async def controls(interaction: discord.Interaction) -> None:
    await interaction.response.send_message("Server controls:", view=ControlsView())
