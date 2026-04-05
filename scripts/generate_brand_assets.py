from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / 'TokenGarden' / 'Assets.xcassets' / 'AppIcon.appiconset'
IMAGES_DIR = ROOT / 'images'


def load_font(size: int, bold: bool = False):
    candidates = [
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf' if bold else '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Helvetica.ttc',
        '/System/Library/Fonts/Supplemental/Tahoma.ttf',
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except Exception:
            continue
    return ImageFont.load_default()


def make_gradient(size: int, top=(55, 197, 139), bottom=(20, 108, 92)):
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    return img


def generate_icon():
    size = 1024
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bg = make_gradient(size)

    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((90, 100, 934, 944), radius=210, fill=(0, 0, 0, 180))
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    canvas.alpha_composite(shadow)

    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((110, 120, 914, 924), radius=190, fill=255)
    rounded_bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    rounded_bg.paste(bg, (0, 0), mask)
    canvas.alpha_composite(rounded_bg)

    draw = ImageDraw.Draw(canvas)
    panel = (250, 265, 774, 740)
    draw.rounded_rectangle(panel, radius=90, fill=(13, 36, 31, 230), outline=(215, 255, 237, 90), width=4)
    draw.rounded_rectangle((250, 265, 774, 360), radius=90, fill=(19, 57, 49, 255))
    for idx, color in enumerate([(255, 120, 120), (255, 204, 102), (70, 220, 140)]):
        x = 315 + idx * 62
        draw.ellipse((x, 304, x + 30, 334), fill=color)

    # terminal prompt lines
    draw.rounded_rectangle((320, 430, 470, 462), radius=14, fill=(115, 255, 189, 255))
    draw.rounded_rectangle((495, 430, 650, 462), radius=14, fill=(73, 155, 120, 255))
    draw.rounded_rectangle((320, 495, 595, 525), radius=14, fill=(56, 122, 97, 255))
    draw.rounded_rectangle((320, 558, 520, 588), radius=14, fill=(56, 122, 97, 255))

    # leaf sprout
    stem_color = (215, 255, 233, 255)
    draw.rounded_rectangle((505, 560, 525, 710), radius=10, fill=stem_color)
    draw.polygon([(515, 535), (570, 585), (520, 625), (465, 575)], fill=(126, 240, 170, 255))
    draw.polygon([(520, 605), (602, 650), (530, 720), (452, 668)], fill=(71, 213, 138, 255))
    draw.ellipse((462, 725, 568, 785), fill=(255, 227, 122, 255))

    for icon_size in [16, 32, 64, 128, 256, 512, 1024]:
        resized = canvas.resize((icon_size, icon_size), Image.LANCZOS)
        resized.save(ICON_DIR / f'icon_{icon_size}.png')


def text(draw, xy, text_value, font, fill, anchor=None):
    draw.text(xy, text_value, font=font, fill=fill, anchor=anchor)


def generate_readme_preview():
    IMAGES_DIR.mkdir(exist_ok=True)
    width, height = 1600, 1000
    img = Image.new('RGB', (width, height), (241, 247, 244))
    draw = ImageDraw.Draw(img)

    title_font = load_font(48, bold=True)
    subtitle_font = load_font(24)
    section_font = load_font(28, bold=True)
    body_font = load_font(22)
    small_font = load_font(18)
    mono_font = load_font(20)

    # background accents
    draw.rounded_rectangle((60, 70, 1540, 930), radius=34, fill=(250, 253, 251), outline=(223, 234, 228), width=2)
    draw.rounded_rectangle((60, 70, 1540, 150), radius=34, fill=(18, 61, 50))

    text(draw, (120, 118), 'Agent Garden', title_font, (255, 255, 255))
    text(draw, (475, 118), 'Codex tokens + Kiro credits in one menu bar app', subtitle_font, (196, 230, 213))

    # left heatmap card
    draw.rounded_rectangle((110, 210, 860, 620), radius=28, fill=(255, 255, 255), outline=(222, 233, 228), width=2)
    text(draw, (145, 250), 'Codex activity', section_font, (31, 56, 48))
    text(draw, (145, 290), 'Daily token heatmap, active sessions, project breakdowns', small_font, (108, 128, 118))

    start_x, start_y = 145, 350
    cell, gap = 18, 8
    greens = [(232, 243, 237), (204, 235, 214), (169, 224, 189), (115, 205, 152), (58, 177, 118), (27, 142, 89)]
    for col in range(18):
        for row in range(7):
            level = (col * 3 + row * 5) % len(greens)
            x = start_x + col * (cell + gap)
            y = start_y + row * (cell + gap)
            draw.rounded_rectangle((x, y, x + cell, y + cell), radius=5, fill=greens[level])

    # right stats card
    draw.rounded_rectangle((920, 210, 1490, 430), radius=28, fill=(255, 255, 255), outline=(222, 233, 228), width=2)
    text(draw, (955, 250), 'Current usage', section_font, (31, 56, 48))
    text(draw, (955, 308), 'Codex 5h', body_font, (93, 112, 103))
    text(draw, (1430, 308), '22%', body_font, (31, 56, 48), anchor='ra')
    draw.rounded_rectangle((955, 336, 1430, 358), radius=11, fill=(226, 235, 231))
    draw.rounded_rectangle((955, 336, 1060, 358), radius=11, fill=(72, 177, 125))
    text(draw, (955, 385), 'Kiro cycle', body_font, (93, 112, 103))
    text(draw, (1430, 385), '165 / 1000 cr', body_font, (31, 56, 48), anchor='ra')

    # bottom cards
    draw.rounded_rectangle((110, 670, 700, 880), radius=28, fill=(255, 255, 255), outline=(222, 233, 228), width=2)
    text(draw, (145, 710), 'Menu bar', section_font, (31, 56, 48))
    draw.rounded_rectangle((145, 760, 665, 828), radius=22, fill=(18, 61, 50))
    text(draw, (185, 793), '🌱  42.6K', mono_font, (239, 255, 247))
    text(draw, (145, 845), 'Icon only / token count / mini graph modes', small_font, (108, 128, 118))

    draw.rounded_rectangle((760, 670, 1490, 880), radius=28, fill=(255, 255, 255), outline=(222, 233, 228), width=2)
    text(draw, (795, 710), 'One glance summary', section_font, (31, 56, 48))
    bullets = [
        '• Codex sessions are parsed from ~/.codex logs in real time',
        '• Kiro credits refresh on demand and on a timer',
        '• Release workflow uploads both ZIP and DMG artifacts',
    ]
    for idx, bullet in enumerate(bullets):
        text(draw, (795, 775 + idx * 34), bullet, body_font, (74, 96, 86))

    img.save(IMAGES_DIR / 'agent-garden-overview.png')


def main():
    generate_icon()
    generate_readme_preview()
    print('Generated app icon set and README preview')


if __name__ == '__main__':
    main()
