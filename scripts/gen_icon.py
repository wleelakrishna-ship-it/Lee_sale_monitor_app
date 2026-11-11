"""One-off script to regenerate the app icon (LA wordmark + fish symbol).
Run with: python scripts/gen_icon.py
Requires Pillow (already present in this environment).
"""
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
CX, CY = SIZE // 2, SIZE // 2
TEAL = (13, 148, 136, 255)  # 0xFF0D9488
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

FONT_PATH = r"C:\Windows\Fonts\seguibl.ttf"  # Segoe UI Black


def draw_fish(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float, color):
    """A simple, modern fish silhouette facing right: oval body + forked tail + dorsal fin."""
    body_w, body_h = 300 * scale, 160 * scale
    body_bbox = (cx - body_w * 0.35, cy - body_h / 2, cx + body_w * 0.65, cy + body_h / 2)
    draw.ellipse(body_bbox, fill=color)

    left_x = body_bbox[0]
    tail = [
        (left_x + 4, cy - body_h * 0.26),
        (left_x - 130 * scale, cy - body_h * 0.78),
        (left_x - 60 * scale, cy),
        (left_x - 130 * scale, cy + body_h * 0.78),
        (left_x + 4, cy + body_h * 0.26),
    ]
    draw.polygon(tail, fill=color)

    fin_cx = cx + body_w * 0.08
    fin = [
        (fin_cx - 60 * scale, cy - body_h * 0.46),
        (fin_cx + 10 * scale, cy - body_h * 0.86),
        (fin_cx + 68 * scale, cy - body_h * 0.42),
    ]
    draw.polygon(fin, fill=color)

    eye_cx = cx + body_w * 0.42
    eye_r = 11 * scale
    draw.ellipse(
        (eye_cx - eye_r, cy - body_h * 0.08 - eye_r, eye_cx + eye_r, cy - body_h * 0.08 + eye_r),
        fill=TEAL if color == WHITE else WHITE,
    )


def build_layer(background):
    img = Image.new("RGBA", (SIZE, SIZE), background)
    draw = ImageDraw.Draw(img)

    fish_cy = CY - 150
    draw_fish(draw, CX + 10, fish_cy, scale=0.85, color=WHITE)

    text = "LA"
    font_size = 300
    font = ImageFont.truetype(FONT_PATH, font_size)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_y = CY + 135
    draw.text(
        (CX - text_w / 2 - bbox[0], text_y - text_h / 2 - bbox[1]),
        text,
        font=font,
        fill=WHITE,
    )
    return img


icon = build_layer(TEAL)
icon.save("assets/icon/icon.png")

foreground = build_layer(TRANSPARENT)
foreground.save("assets/icon/icon_foreground.png")

print("done")
