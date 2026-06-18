"""Render a player's position onto the SCUM map image."""
import io
import logging

from PIL import Image, ImageDraw, ImageFont

from config import settings

log = logging.getLogger("sidecar.map")


def world_to_pixel(x: float, y: float, img_w: int, img_h: int) -> tuple[int, int]:
    """Map in-game world coords to image pixels via linear calibration.

    Image Y grows downward, so the Y axis is flipped. If your map ends up
    mirrored, swap the min/max for that axis in config.
    """
    fx = (x - settings.world_min_x) / (settings.world_max_x - settings.world_min_x)
    fy = (y - settings.world_min_y) / (settings.world_max_y - settings.world_min_y)
    px = int(fx * img_w)
    py = int((1.0 - fy) * img_h)
    # Keep the marker on-canvas even if coords fall slightly outside calibration.
    px = max(0, min(img_w - 1, px))
    py = max(0, min(img_h - 1, py))
    return px, py


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def render_ping(player: str, x: float, y: float) -> bytes:
    """Return a PNG (bytes) of the map with the player's position marked."""
    base = Image.open(settings.map_image_path).convert("RGBA")
    draw = ImageDraw.Draw(base)
    px, py = world_to_pixel(x, y, base.width, base.height)
    # Calibration aid: log exactly what the current bounds did with these coords.
    fx = (x - settings.world_min_x) / (settings.world_max_x - settings.world_min_x)
    fy = (y - settings.world_min_y) / (settings.world_max_y - settings.world_min_y)
    log.info(
        "render %r world=(%.1f, %.1f) -> px=(%d, %d) of (%d, %d)  frac=(%.3f, %.3f)  "
        "bounds x[%.0f..%.0f] y[%.0f..%.0f]",
        player, x, y, px, py, base.width, base.height, fx, fy,
        settings.world_min_x, settings.world_max_x, settings.world_min_y, settings.world_max_y,
    )

    # Crosshair + dot marker.
    r = max(8, base.width // 100)
    red = (220, 40, 40, 255)
    white = (255, 255, 255, 255)
    draw.line([(px - r * 2, py), (px + r * 2, py)], fill=white, width=2)
    draw.line([(px, py - r * 2), (px, py + r * 2)], fill=white, width=2)
    draw.ellipse([(px - r, py - r), (px + r, py + r)], outline=white, width=3)
    draw.ellipse([(px - r + 3, py - r + 3), (px + r - 3, py + r - 3)], fill=red)

    # Player name label with a backing box for readability.
    font = _font(max(14, base.width // 40))
    label = player
    tb = draw.textbbox((0, 0), label, font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    lx, ly = px + r * 2 + 4, py - th // 2
    draw.rectangle([(lx - 4, ly - 4), (lx + tw + 4, ly + th + 4)], fill=(0, 0, 0, 160))
    draw.text((lx, ly), label, fill=white, font=font)

    buf = io.BytesIO()
    base.save(buf, format="PNG")
    return buf.getvalue()
