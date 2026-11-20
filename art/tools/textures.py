"""Paint the UV atlases from the same design sheets as the meshes (Pillow/NumPy)."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from car_profiles import CARS, STATIONS

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/textures"
CAR_ATLAS = ROOT / "assets/models/cars/atlas"
CELL = 128
GRID = 4
FONTS = Path("/usr/share/fonts/truetype/dejavu")


def font(size, mono=False):
    path = "DejaVuSansMono-Bold.ttf" if mono else "DejaVuSansCondensed-Bold.ttf"
    try:
        return ImageFont.truetype(str(FONTS / path), size)
    except OSError:
        return ImageFont.load_default(size=size)


def rgb(value):
    return tuple(int(value.strip("#")[i:i + 2], 16) for i in (0, 2, 4))


def grain(color, seed=0, noise=2.0, light=0.08, height=CELL, width=CELL):
    if isinstance(color, str):
        color = rgb(color)
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, height)[:, None]
    x = np.linspace(0, 1, width)[None, :]
    cloudy = 1 + light * (.65 - y + .15 * np.cos(x * 12 + y * 6))
    variation = rng.normal(0, noise, (height, width))
    return Image.fromarray(np.uint8(np.clip(np.array(color)[None, None, :] * cloudy[:, :, None]
                                          + variation[:, :, None], 0, 255)))


def atlas(tiles, name, columns=GRID, rows=GRID):
    sheet = Image.new("RGB", (columns * CELL, rows * CELL))
    for index, tile in enumerate(tiles):
        sheet.paste(tile, (index % columns * CELL, index // columns * CELL))
    sheet.save(OUT / name, optimize=True)


def car_trim():
    colors = ["#2b3036", "#141c23", "#a0a6a7", "#44484b", "#f6dca8", "#cc7e33",
              "#de5260", "#293741", "#393b40", "#8a9190", "#626260", "#344954",
              "#14191f", "#bfbb9f", "#0f1319", "#60494a"]
    tiles = [grain(value, i, 1.6) for i, value in enumerate(colors)]
    d = ImageDraw.Draw(tiles[1])
    for y in range(5, 128, 10):
        for x in range(-12, 128, 12):
            i = x + (y % 20 == 5) * 6
            d.polygon([(i, y + 3), (i + 3, y), (i + 9, y), (i + 12, y + 3),
                       (i + 9, y + 7), (i + 3, y + 7)], outline=rgb("#354047"))
    d = ImageDraw.Draw(tiles[0])
    for y in range(-12, 140, 16):
        d.line([(10, y), (48, y + 6), (68, y + 2), (115, y + 8)], "#161a20", 3)
        d.line([(13, y + 2), (48, y + 8), (68, y + 4), (113, y + 10)], "#363b40", 1)
    for index, edge, shine in [(4, "#a9997b", "#fff3d6"), (5, "#8f4d29", "#f9bb6e"), (6, "#8b2639", "#ff8a89")]:
        d = ImageDraw.Draw(tiles[index])
        for x in range(3, 128, 9):
            d.line([(x, 0), (x, 128)], edge, 1)
        d.rounded_rectangle((11, 26, 116, 71), 19, outline=shine, width=4)
        d.line([(20, 22), (98, 22)], shine, 2)
    d = ImageDraw.Draw(tiles[3])
    d.arc((24, 28, 105, 102), 35, 320, "#777c7c", 3)
    for i in range(4):
        d.line([(29 + i * 24, 63), (38 + i * 24, 65)], "#b6a094", 2)
    d = ImageDraw.Draw(tiles[7])
    d.line((27, 15, 77, 148), "#3e5461", 20)
    d.line((69, -24, 103, 123), "#415867", 7)
    d = ImageDraw.Draw(tiles[9])
    for y in range(0, 128, 4):
        d.line(((0, y), (127, y)), "#a8aaa3", 1)
    d = ImageDraw.Draw(tiles[13])
    d.rounded_rectangle((3, 18, 124, 111), 8, outline="#646c65", width=4)
    d.rectangle((9, 25, 118, 40), "#606b67")
    d.text((64, 37), "LITORAL", "#e9ddbe", font(15), anchor="ms")
    d.text((64, 91), "AT • 04", "#232b2e", font(23, True), anchor="ms")
    d.line((33, 101, 95, 101), "#767e74", 2)
    atlas(tiles, CAR_ATLAS / "coach_trim.png")


def coachwork(key, spec, index):
    (width, height, length), _, _, _, _, decks, _, cabin, front, _, _, _, _ = spec
    x = np.linspace(0, 1, CELL)[None, :]
    y = np.linspace(0, 1, CELL)[:, None]
    tone = 246 - 31 * y ** 2 - 16 * np.exp(-((y - .785) / .038)**2)
    tone = tone + 6 * np.cos(x * np.pi) + 5 * np.sin(x * 13 + y * 3)
    solid = np.repeat(np.clip(tone, 0, 254)[:, :, None], 3, axis=2)
    side = Image.fromarray(np.uint8(solid))
    top = grain("#f2f1ec", index, .66, .036)
    fascia = grain("#d7d9da", index, .75, .15)
    clean = grain("#f4f2ef", index, .75, .04)
    d = ImageDraw.Draw(side)
    a, _, _, b, _, _, pillar = cabin

    def pt(t, real_y):
        return (round(3 + t * 121), round(124 - real_y / height * 121))

    start = a + .058
    end = min(.77, b - .08) if key in {"fenda_30", "trovao_68", "iris_22", "alvor_72", "vektor_v8", "miragem_r"} else b - .10
    join = np.interp(start, STATIONS, decks)
    sill = .25 if key not in {"miragem_r", "fenda_30", "alvor_72"} else .19
    d.line([pt(start, join + .008), pt(start-.012, .54), pt(start+.008, sill + .05),
            pt(start+.035, sill), pt(end-.022, sill), pt(end, sill+.035), pt(end, np.interp(end, STATIONS, decks)-.016)],
           "#adadad", 1)
    # Shadow, lip and catchlight of the flush door release.
    for t in [end - .07] if key in {"fenda_30", "trovao_68", "iris_22", "alvor_72", "vektor_v8", "miragem_r"} else [pillar - .063, end - .052]:
        px, py = pt(t, np.interp(t, STATIONS, decks) - (.11 if key == "brasa_16" else .067))
        d.rounded_rectangle((px-3, py-1, px+4, py+1), 1, fill="#747477")
        d.line((px-2, py-1, px+2, py-1), "#eae7df")
    if key in {"brasa_16", "monte_gt", "trovao_68", "alvor_72"}:
        strip_y = {"brasa_16": .46, "monte_gt": .54, "trovao_68": .48, "alvor_72": .30}[key]
        d.line([pt(.065, strip_y), pt(.29, strip_y + .015), pt(.74, strip_y + .017), pt(.93, strip_y + .035)],
               "#a5a8a6", 1)
    if key in {"vetra_x", "vektor_v8", "miragem_r"}:
        d.polygon([pt(.68, .326), pt(.75, .455), pt(.772, .443), pt(.75, .325)], fill="#74787b")
        d.line([pt(.68, .326), pt(.75, .455)], "#d8d8d8")
    if key == "furgao_servico":
        d.rectangle([pt(.494,1.245),pt(.867,.936)],fill="#b8bab8")
        d.text(pt(.517,1.19),"VIGÍLIA",fill="#727a79",font=font(12))
        d.line([pt(.505,.80),pt(.905,.80)],"#ababab",2)
        d.line([pt(.875,1.47),pt(.878,.314)],"#aaa8a3",1)
    d = ImageDraw.Draw(top)
    deck_t = min(.28, a - .016)
    hood = [(round(.046*121+3), 38), (round(deck_t*121+3), 27), (round(deck_t*121+3), 101),
            (round(.046*121+3), 90), (round(.046*121+3), 38)]
    d.line(hood, "#b3b5b6", 1)
    d.line((deck_t*121+1, 48, deck_t*121+1, 80), "#72777b", 2)
    if front == "pop":
        for y in [31, 81]:
            d.polygon([(12, y), (27, y-3), (28, y+17), (12, y+18)], outline="#999c9f")
    if key in {"vetra_x", "miragem_r"}:
        for y in [45, 77]:
            for i in range(3):
                d.line((22 + 2*i, y, 22 + 2*i, y+8), "#9f9fa0", 1)
    d = ImageDraw.Draw(fascia)
    d.rectangle((0, 87, 128, 127), fill="#aaadb0")
    d.line((0, 82, 128, 82), "#e6e8e5", 1)
    atlas([side, top, fascia, clean], CAR_ATLAS / f"finish_{key}.png")


if __name__ == "__main__":
    CAR_ATLAS.mkdir(parents=True, exist_ok=True)
    car_trim()
    for i, (key, spec) in enumerate(CARS.items()):
        coachwork(key, spec, i)
