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

    @discord.ui.button(label="Ping Green", style=discord.ButtonStyle.success)
    async def ping_green(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        await self._queue(interaction, "green")

    @discord.ui.button(label="Ping Red", style=discord.ButtonStyle.danger)
    async def ping_red(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        await self._queue(interaction, "red")


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
