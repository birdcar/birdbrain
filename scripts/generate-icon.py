# /// script
# requires-python = ">=3.11"
# dependencies = ["Pillow"]
# ///
"""Generate Birdbrain app icon using Catppuccin Mocha palette."""

import math
from PIL import Image, ImageDraw

# Catppuccin Mocha palette
BASE = "#1e1e2e"
MANTLE = "#181825"
CRUST = "#11111b"
SURFACE0 = "#313244"
SURFACE1 = "#45475a"
MAUVE = "#cba6f7"
PINK = "#f5c2e7"
LAVENDER = "#b4befe"
BLUE = "#89b4fa"
TEAL = "#94e2d5"
GREEN = "#a6e3a1"
YELLOW = "#f9e2af"
PEACH = "#fab387"
RED = "#f38ba8"
TEXT = "#cdd6f4"
SUBTEXT0 = "#a6adc8"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def draw_bird_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / 1024  # scale factor

    # Rounded square background
    margin = int(80 * s)
    radius = int(220 * s)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=hex_to_rgb(BASE),
    )

    # Subtle inner glow ring
    inner_margin = int(95 * s)
    draw.rounded_rectangle(
        [inner_margin, inner_margin, size - inner_margin, size - inner_margin],
        radius=int(205 * s),
        outline=hex_to_rgb(SURFACE0),
        width=int(3 * s),
    )

    cx, cy = size // 2, int(520 * s)

    # Body — rounded mauve blob
    body_w, body_h = int(320 * s), int(340 * s)
    body_box = [cx - body_w, cy - body_h + int(40 * s), cx + body_w, cy + body_h]
    draw.ellipse(body_box, fill=hex_to_rgb(MAUVE))

    # Belly — lighter pink oval
    belly_w, belly_h = int(200 * s), int(220 * s)
    belly_cy = cy + int(60 * s)
    draw.ellipse(
        [cx - belly_w, belly_cy - belly_h, cx + belly_w, belly_cy + belly_h],
        fill=hex_to_rgb(PINK),
    )

    # Head — larger circle on top
    head_r = int(220 * s)
    head_cy = cy - int(250 * s)
    draw.ellipse(
        [cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
        fill=hex_to_rgb(MAUVE),
    )

    # "Brain" pattern on head — swirly lines in lavender
    # Three curved lines suggesting a brain
    brain_cx, brain_cy = cx, head_cy - int(30 * s)
    brain_r = int(130 * s)

    # Brain bumps — overlapping circles
    offsets = [
        (-60, -50, 85),
        (50, -55, 80),
        (-10, -75, 75),
        (-70, -10, 70),
        (60, -5, 72),
        (0, -30, 90),
    ]
    for ox, oy, r in offsets:
        bx = brain_cx + int(ox * s)
        by = brain_cy + int(oy * s)
        br = int(r * s)
        draw.ellipse([bx - br, by - br, bx + br, by + br], fill=hex_to_rgb(LAVENDER))

    # Brain center highlight
    for ox, oy, r in [(-25, -45, 50), (30, -40, 45), (0, -60, 40)]:
        bx = brain_cx + int(ox * s)
        by = brain_cy + int(oy * s)
        br = int(r * s)
        draw.ellipse([bx - br, by - br, bx + br, by + br], fill=hex_to_rgb(BLUE))

    # Brain squiggle line — the dividing line
    line_w = int(6 * s)
    points = []
    for i in range(20):
        t = i / 19
        x = brain_cx + int(math.sin(t * math.pi * 2.5) * 30 * s)
        y = brain_cy - int(110 * s) + int(t * 180 * s)
        points.append((x, y))
    if len(points) > 1:
        draw.line(points, fill=hex_to_rgb(MAUVE), width=line_w, joint="curve")

    # Eyes — large cute eyes
    eye_y = head_cy + int(30 * s)
    eye_spacing = int(90 * s)
    eye_r = int(45 * s)
    pupil_r = int(28 * s)
    shine_r = int(12 * s)

    for side in [-1, 1]:
        ex = cx + side * eye_spacing
        # Eye white
        draw.ellipse(
            [ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r],
            fill=hex_to_rgb(TEXT),
        )
        # Pupil
        px = ex + side * int(10 * s)
        draw.ellipse(
            [px - pupil_r, eye_y - pupil_r, px + pupil_r, eye_y + pupil_r],
            fill=hex_to_rgb(CRUST),
        )
        # Shine
        sx = px - int(8 * s)
        sy = eye_y - int(10 * s)
        draw.ellipse(
            [sx - shine_r, sy - shine_r, sx + shine_r, sy + shine_r],
            fill=(255, 255, 255, 220),
        )

    # Beak — small orange triangle
    beak_cx = cx
    beak_top = head_cy + int(85 * s)
    beak_w = int(40 * s)
    beak_h = int(35 * s)
    draw.polygon(
        [
            (beak_cx - beak_w, beak_top),
            (beak_cx + beak_w, beak_top),
            (beak_cx, beak_top + beak_h),
        ],
        fill=hex_to_rgb(PEACH),
    )

    # Cheeks — subtle blush circles
    cheek_r = int(35 * s)
    cheek_y = head_cy + int(65 * s)
    for side in [-1, 1]:
        chx = cx + side * int(150 * s)
        # Semi-transparent pink
        cheek_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
        cheek_draw = ImageDraw.Draw(cheek_img)
        r, g, b = hex_to_rgb(RED)
        cheek_draw.ellipse(
            [chx - cheek_r, cheek_y - cheek_r, chx + cheek_r, cheek_y + cheek_r],
            fill=(r, g, b, 80),
        )
        img = Image.alpha_composite(img, cheek_img)
        draw = ImageDraw.Draw(img)

    # Wings — small curved shapes on sides
    wing_y = cy - int(30 * s)
    wing_w, wing_h = int(120 * s), int(160 * s)
    for side in [-1, 1]:
        wx = cx + side * int(280 * s)
        draw.ellipse(
            [wx - wing_w, wing_y - wing_h, wx + wing_w, wing_y + wing_h],
            fill=hex_to_rgb(LAVENDER),
        )

    # Feet — two little orange ovals at bottom
    feet_y = cy + int(310 * s)
    foot_w, foot_h = int(55 * s), int(25 * s)
    for side in [-1, 1]:
        fx = cx + side * int(100 * s)
        draw.ellipse(
            [fx - foot_w, feet_y - foot_h, fx + foot_w, feet_y + foot_h],
            fill=hex_to_rgb(PEACH),
        )

    # Terminal cursor — small blinking underscore at bottom right (nod to CLI)
    cursor_x = cx + int(180 * s)
    cursor_y = cy + int(250 * s)
    cursor_w, cursor_h = int(30 * s), int(6 * s)
    draw.rectangle(
        [cursor_x, cursor_y, cursor_x + cursor_w, cursor_y + cursor_h],
        fill=hex_to_rgb(GREEN),
    )

    return img


def main():
    import os
    import subprocess
    import tempfile

    icon = draw_bird_icon(1024)

    # Create iconset
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    for size in sizes:
        resized = icon.resize((size, size), Image.LANCZOS)

        if size <= 512:
            resized.save(os.path.join(iconset_dir, f"icon_{size}x{size}.png"))
        if size <= 1024:
            half = size // 2
            if half >= 16:
                resized.save(
                    os.path.join(iconset_dir, f"icon_{half}x{half}@2x.png")
                )

    # Convert to .icns
    out_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "assets",
        "AppIcon.icns",
    )
    # Also save a PNG preview
    preview_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "assets",
        "icon-preview.png",
    )
    icon.save(preview_path)

    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", out_path], check=True)
    print(f"Generated {out_path}")
    print(f"Preview saved to {preview_path}")


if __name__ == "__main__":
    main()
