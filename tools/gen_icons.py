# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11"]
# ///
# usage: uv run tools/gen_icons.py
# Draws the launcher icon at the size the Venu 3 expects, and the weather, sun-time and steps icons.
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = {'resources': 70}
SCREENS = {'resources': 454}
# Pillow draws shapes without antialiasing, so draw large and scale down
SUPERSAMPLE = 8
BACKGROUND = '#1E1F22'


def draw_icon(n: int) -> Image.Image:
    s = n * SUPERSAMPLE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, s - 1, s - 1), radius=s * 0.22, fill=BACKGROUND)

    font = ImageFont.truetype(os.path.join(HERE, 'fonts', 'Inter-Regular.ttf'), s * 0.29)
    ascent, descent = font.getmetrics()
    tile_w, tile_h, gap = s * 0.40, s * 0.46, s * 0.035
    top = (s - tile_h) / 2
    mid = top + tile_h / 2
    radius = s * 0.045
    for i, digits in enumerate(('10', '08')):
        x = s / 2 - gap / 2 - tile_w if i == 0 else s / 2 + gap / 2
        draw.rounded_rectangle((x, top, x + tile_w, top + tile_h), radius=radius, fill='#C9C9C9')
        draw.rounded_rectangle((x, top, x + tile_w, mid), radius=radius, fill='#F4F4F4',
                               corners=(True, True, False, False))
        baseline = mid + (ascent - descent) / 2
        draw.text((x + (tile_w - font.getlength(digits)) / 2, baseline), digits, font=font,
                  fill='black', anchor='ls')
        hinge = max(SUPERSAMPLE, s * 0.016)
        draw.rectangle((x, mid - hinge / 2, x + tile_w, mid + hinge / 2), fill=BACKGROUND)
    return img.resize((n, n), Image.LANCZOS)



def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def rgb(hex_color: str) -> tuple:
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def shaded(img: Image.Image, mask: Image.Image, top: str, bottom: str) -> None:
    box = mask.getbbox()
    if box is None:
        return
    gradient = Image.new('RGBA', img.size)
    g = ImageDraw.Draw(gradient)
    for y in range(box[1], box[3]):
        g.line((0, y, img.width, y), fill=lerp(rgb(top), rgb(bottom), (y - box[1]) / max(1, box[3] - box[1] - 1)) + (255,))
    img.paste(gradient, (0, 0), mask)


def sun(img: Image.Image, cx: float, cy: float, r: float) -> None:
    rings = 40
    draw = ImageDraw.Draw(img)
    for i in range(rings):
        t = i / rings
        rr = r * (1 - 0.8 * t)
        ox, oy = cx - r * 0.3 * t, cy - r * 0.3 * t
        draw.ellipse((ox - rr, oy - rr, ox + rr, oy + rr), fill=lerp(rgb('#F07848'), rgb('#FFD49A'), t) + (255,))


def moon(img: Image.Image, cx: float, cy: float, r: float) -> None:
    mask = Image.new('L', img.size, 0)
    m = ImageDraw.Draw(mask)
    m.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    m.ellipse((cx - r * 0.35, cy - r * 1.25, cx + r * 1.55, cy + r * 0.55), fill=0)
    shaded(img, mask, '#FBEFB8', '#D8BD6A')


def cloud(img: Image.Image, cx: float, cy: float, s: float, top: str, bottom: str, edge: str) -> None:
    def shape(grow: float) -> Image.Image:
        mask = Image.new('L', img.size, 0)
        m = ImageDraw.Draw(mask)
        for bx, by, br in ((-0.22, 0.06, 0.2), (0.04, -0.1, 0.27), (0.27, 0.07, 0.19)):
            rr = (br + grow) * s
            m.ellipse((cx + bx * s - rr, cy + by * s - rr, cx + bx * s + rr, cy + by * s + rr), fill=255)
        m.rounded_rectangle((cx - (0.42 + grow) * s, cy + 0.02 * s, cx + (0.46 + grow) * s, cy + (0.26 + grow) * s),
                            radius=(0.12 + grow) * s, fill=255)
        return mask
    img.paste(Image.new('RGBA', img.size, rgb(edge) + (255,)), (0, 0), shape(0.02))
    shaded(img, shape(0.0), top, bottom)


LIGHT_CLOUD = ('#FFFFFF', '#C9CED4', '#7C838B')
GREY_CLOUD = ('#D9DDE2', '#9AA1A9', '#5E656D')
DARK_CLOUD = ('#9AA1A9', '#5E656D', '#3C4248')


def drops(img: Image.Image, cx: float, top: float, s: float, count: int, color: str) -> None:
    draw = ImageDraw.Draw(img)
    for k in range(count):
        x = cx + (k - (count - 1) / 2) * s * 0.2
        draw.line((x + s * 0.03, top, x - s * 0.03, top + s * 0.14), fill=rgb(color) + (255,), width=max(2, round(s * 0.05)))


def weather_icon(name: str, n: int) -> Image.Image:
    s = n * SUPERSAMPLE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    c = s / 2
    if name == 'WeatherClearDay':
        sun(img, c, c, s * 0.34)
    elif name == 'WeatherClearNight':
        moon(img, c, c, s * 0.36)
    elif name in ('WeatherPartlyDay', 'WeatherShowers'):
        sun(img, s * 0.64, s * 0.36, s * 0.24)
        cloud(img, s * 0.44, s * 0.6, s * 0.82, *LIGHT_CLOUD)
        if name == 'WeatherShowers':
            drops(img, s * 0.44, s * 0.84, s, 3, '#5BA8FF')
    elif name == 'WeatherPartlyNight':
        moon(img, s * 0.66, s * 0.34, s * 0.24)
        cloud(img, s * 0.44, s * 0.6, s * 0.82, *LIGHT_CLOUD)
    elif name == 'WeatherCloudy':
        cloud(img, s * 0.62, s * 0.4, s * 0.6, *GREY_CLOUD)
        cloud(img, s * 0.42, s * 0.6, s * 0.82, *LIGHT_CLOUD)
    elif name == 'WeatherFog':
        cloud(img, c, s * 0.42, s * 0.82, *GREY_CLOUD)
        draw = ImageDraw.Draw(img)
        for k, (x0, x1) in enumerate(((0.18, 0.7), (0.3, 0.84), (0.2, 0.62))):
            y = s * (0.72 + k * 0.09)
            draw.rounded_rectangle((s * x0, y, s * x1, y + s * 0.04), radius=s * 0.02, fill=rgb('#AEB4BB') + (255,))
    elif name in ('WeatherDrizzle', 'WeatherRain'):
        cloud(img, c, s * 0.42, s * 0.86, *GREY_CLOUD)
        drops(img, c, s * 0.7, s, 2 if name == 'WeatherDrizzle' else 3, '#5BA8FF')
    elif name == 'WeatherSnow':
        cloud(img, c, s * 0.42, s * 0.86, *LIGHT_CLOUD)
        draw = ImageDraw.Draw(img)
        for k in range(3):
            x, y, r = s * (0.3 + k * 0.2), s * (0.78 + (k % 2) * 0.08), s * 0.045
            draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 255))
    elif name == 'WeatherThunder':
        cloud(img, c, s * 0.4, s * 0.86, *DARK_CLOUD)
        ImageDraw.Draw(img).polygon([(s * 0.52, s * 0.62), (s * 0.38, s * 0.8), (s * 0.48, s * 0.8), (s * 0.42, s * 0.96),
                                     (s * 0.62, s * 0.74), (s * 0.52, s * 0.74), (s * 0.58, s * 0.62)],
                                    fill=rgb('#FFD54F') + (255,))
    return img.resize((n, n), Image.LANCZOS)


def sun_time_icon(rising: bool, n: int) -> Image.Image:
    s = n * SUPERSAMPLE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = rgb('#FFB74D' if rising else '#FF8A65') + (255,)
    horizon = s * 0.78
    draw.pieslice((s * 0.2, horizon - s * 0.3, s * 0.8, horizon + s * 0.3), 180, 360, fill=color)
    draw.rectangle((s * 0.05, horizon, s * 0.95, horizon + s * 0.08), fill=color)
    tip, base = (s * 0.08, s * 0.3) if rising else (s * 0.3, s * 0.08)
    draw.polygon([(s * 0.5, tip), (s * 0.34, base), (s * 0.66, base)], fill=color)
    return img.resize((n, n), Image.LANCZOS)


def steps_icon(n: int) -> Image.Image:
    s = n * SUPERSAMPLE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    blue = rgb('#5BA8FF') + (255,)
    draw.rounded_rectangle((s * 0.12, s * 0.5, s * 0.42, s * 0.9), radius=s * 0.1, fill=blue)
    draw.rounded_rectangle((s * 0.56, s * 0.1, s * 0.86, s * 0.5), radius=s * 0.1, fill=blue)
    return img.resize((n, n), Image.LANCZOS)


WEATHER = ['WeatherClearDay', 'WeatherClearNight', 'WeatherPartlyDay', 'WeatherPartlyNight', 'WeatherCloudy',
           'WeatherFog', 'WeatherDrizzle', 'WeatherRain', 'WeatherSnow', 'WeatherShowers', 'WeatherThunder']

for folder, size in SIZES.items():
    os.makedirs(os.path.join(HERE, '..', folder, 'drawables'), exist_ok=True)
    draw_icon(size).save(os.path.join(HERE, '..', folder, 'drawables', 'launcher_icon.png'))

for folder, width in SCREENS.items():
    out = os.path.join(HERE, '..', folder, 'drawables')
    images = {name: weather_icon(name, round(width * 0.19)) for name in WEATHER}
    images['SunriseIcon'] = sun_time_icon(True, round(width * 0.05))
    images['SunsetIcon'] = sun_time_icon(False, round(width * 0.05))
    images['StepsIcon'] = steps_icon(round(width * 0.045))
    entries = []
    for name, image in images.items():
        file = name.lower() + '.png'
        image.save(os.path.join(out, file))
        entries.append(f'    <bitmap id="{name}" filename="{file}"/>')
    with open(os.path.join(out, 'icons.xml'), 'w') as f:
        f.write('<drawables>\n' + '\n'.join(entries) + '\n</drawables>\n')
