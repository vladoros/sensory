# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11"]
# ///
# usage: uv run tools/gen_fonts.py
# Writes the Inter and Roboto bitmap fonts (png atlas, BMFont .fnt and fonts.xml) for the Venu 3 screen.
import glob
import os
import re
from typing import NamedTuple

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DEVICES = {'resources': 454}
ATLAS_WIDTH = 512

DIGITS = '0123456789'
LATIN = ''.join(chr(c) for c in [*range(32, 127), *range(0xA0, 0x180), *range(0x218, 0x21C)] if c not in (0xAD, 0x149))
CYRILLIC = ''.join(chr(c) for c in range(0x410, 0x450)) + 'ёЁіІўЎ'
TEXT = LATIN + CYRILLIC + '…'


class Role(NamedTuple):
    name: str
    weight: str
    px_at_454: int
    chars: str
    # Tile digits: '0' is squeezed to this width/height ratio, digits sit in equal cells, the line box hugs them
    digit_aspect: float | None = None


class FontSpec(NamedTuple):
    id: str
    ttf: str
    px_at_454: int
    chars: str
    digit_aspect: float | None


FAMILIES = ['Inter', 'Roboto']
# The hairline digits need each family's thinnest weight that still reads at a glance
HAIRLINE = {'Inter': 'ExtraLight', 'Roboto': 'Thin'}
ROLES = [
    Role('Digits', 'Hairline', 131, DIGITS, digit_aspect=0.60),
    Role('Temp', 'Hairline', 54, '-' + DIGITS + '°'),
    Role('City', 'Bold', 27, TEXT),
    Role('Cond', 'Bold', 23, TEXT),
    Role('Small', 'Regular', 18, DIGITS + '%:.°- /kmph'),
    Role('Big', 'Regular', 34, TEXT),
]
FONTS = [FontSpec(family + role.name, f'{family}-{HAIRLINE[family] if role.weight == "Hairline" else role.weight}.ttf',
                  role.px_at_454, role.chars, role.digit_aspect)
         for family in FAMILIES for role in ROLES]


class Glyph(NamedTuple):
    char: str
    image: Image.Image | None
    left: int
    top: int
    width: int
    height: int
    advance: int


# font.getbbox is a loose layout box, so crop each rendered glyph to its inked pixels
def render(font: ImageFont.FreeTypeFont, char: str) -> Glyph:
    advance = round(font.getlength(char))
    empty = Glyph(char, None, 0, font.getmetrics()[0], 0, 0, advance)
    left, top, right, bottom = font.getbbox(char)
    if right <= left or bottom <= top:
        return empty
    canvas = Image.new('L', (right - left, bottom - top), 0)
    ImageDraw.Draw(canvas).text((-left, -top), char, font=font, fill=255)
    ink = canvas.getbbox()
    if ink is None:
        return empty
    x0, y0, x1, y1 = ink
    return Glyph(char, canvas.crop(ink), left + x0, top + y0, x1 - x0, y1 - y0, advance)


def squeezed(g: Glyph, factor: float) -> Glyph:
    if g.image is None:
        return g._replace(advance=round(g.advance * factor))
    width = max(1, round(g.width * factor))
    # Box filtering: Lanczos rings at the edges, and the watch renders those rings as visible outlines
    return g._replace(image=g.image.resize((width, g.height), Image.BOX), width=width,
                      left=round(g.left * factor), advance=round(g.advance * factor))


def write_font(spec: FontSpec, px: float, base: str) -> None:
    font = ImageFont.truetype(os.path.join(HERE, 'fonts', spec.ttf), px)
    ascent, descent = font.getmetrics()
    glyphs = [render(font, char) for char in dict.fromkeys(spec.chars)]
    line_height, baseline = ascent + descent, ascent
    if spec.digit_aspect:
        zero = next(g for g in glyphs if g.char == '0')
        glyphs = [squeezed(g, spec.digit_aspect * zero.height / zero.width) for g in glyphs]
        inked = [g for g in glyphs if g.image is not None]
        top = min(g.top for g in inked)
        line_height = max(g.top + g.height for g in inked) - top
        baseline = ascent - top
        cell = next(g for g in glyphs if g.char == '0').width
        cell += round(line_height * 0.07)
        glyphs = [g._replace(top=g.top - top, left=(cell - g.width) // 2, advance=cell) for g in glyphs]

    positions = {}
    x, y, shelf = 1, 1, 0
    for g in sorted(glyphs, key=lambda g: -g.height):
        if x + g.width + 1 > ATLAS_WIDTH:
            x, y, shelf = 1, y + shelf + 1, 0
        positions[g.char] = (x, y)
        x += g.width + 1
        shelf = max(shelf, g.height)
    height = y + shelf + 1

    mask = Image.new('L', (ATLAS_WIDTH, height), 0)
    for g in glyphs:
        if g.image is not None:
            mask.paste(g.image, positions[g.char])
    atlas = Image.new('RGBA', mask.size, (255, 255, 255, 0))
    atlas.putalpha(mask)
    atlas.save(base + '.png')

    lines = [
        f'info face="{font.getname()[0]}" size={round(px)} bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
        f'common lineHeight={line_height} base={baseline} scaleW={ATLAS_WIDTH} scaleH={height} pages=1 packed=0',
        f'page id=0 file="{os.path.basename(base)}.png"',
        f'chars count={len(glyphs)}',
    ]
    for g in glyphs:
        gx, gy = positions[g.char]
        lines.append(f'char id={ord(g.char)} x={gx} y={gy} width={g.width} height={g.height} '
                     f'xoffset={g.left} yoffset={g.top} xadvance={g.advance} page=0 chnl=15')
    with open(base + '.fnt', 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')



def missing_from_text_fonts() -> str:
    used = set()
    for path in glob.glob(os.path.join(HERE, '..', 'source', '*.mc')):
        for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', open(path, encoding='utf-8').read()):
            used |= set(re.sub(r'\\u([0-9A-Fa-f]{4})', lambda m: chr(int(m.group(1), 16)), literal))
    return ''.join(sorted(c for c in used if c >= ' ' and c not in TEXT))


missing = missing_from_text_fonts()
if missing:
    raise SystemExit(f'source strings use characters the fonts lack, add them to TEXT: {missing}')

for folder, width in DEVICES.items():
    out_dir = os.path.join(HERE, '..', folder, 'fonts')
    os.makedirs(out_dir, exist_ok=True)
    for spec in FONTS:
        write_font(spec, spec.px_at_454 * width / 454, os.path.join(out_dir, spec.id.lower()))
    entries = [f'    <font id="{s.id}" filename="{s.id.lower()}.fnt" antialias="true"/>' for s in FONTS]
    with open(os.path.join(out_dir, 'fonts.xml'), 'w') as f:
        f.write('<fonts>\n' + '\n'.join(entries) + '\n</fonts>\n')
