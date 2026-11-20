"""The fabric, face, stitching, and sponsor markings share one atlas per character."""
from PIL import ImageDraw

from cast_profiles import CAST
from textures import OUT, atlas, font, grain, rgb


def palette(color, weight):
    return tuple(min(255, round(c * weight)) for c in rgb(color))


def paint(id, profile, seed):
    _, _, _, _, _, _, cut, style, coat, liner, pants, skin, hair, shoes = profile
    items = [coat, coat, coat, pants, skin, hair, shoes, liner, skin, pants, skin, coat]
    tiles = [grain(color, index + seed, 1.7, .16 if index < 4 else .075)
             for index, color in enumerate(items)]
    ink = palette(coat, .53)
    thread = palette(coat, 1.24)
    leather = palette(shoes, .72)
    accent = rgb(liner)
    deep = palette(pants, .63)

    d = ImageDraw.Draw(tiles[0])
    if style == "malha":
        d.arc((41,-15,90,35), 2, 178, ink, 5)
        d.arc((43,-10,87,35), 2, 178, thread, 2)
        if id == "sol":
            d.line([(2,77),(31,79),(94,80),(125,75)], thread, 4)
            d.line([(6,84),(55,87),(125,82)], ink, 1)
    elif style == "oficina":
        d.polygon([(49,4),(79,4),(72,23),(63,42),(51,21)], fill=accent)
        d.line([(63,42),(64,119)], ink, 2)
        d.line([(67,42),(68,119)], thread)
        for yy in range(49,114,18):
            d.ellipse((62,yy,65,yy+3),fill=accent)
        for x in (25,82):
            d.line([(x,67),(x+4,76),(x+17,76),(x+22,66)],ink,2)
    else:
        depth = 37 if style == "aviadora" else 45
        d.polygon([(51,4),(77,4),(70,depth-9),(62,depth),(55,depth-13)], fill=accent)
        d.line([(63,depth),(62,87),(63,126)], ink, 2)
        d.line([(65,depth),(65,120)], thread)
        d.line([(56,8),(47,34),(28,48)], thread, 2)
        d.line([(73,8),(81,34),(102,46)], thread, 2)
    if style in ("piloto", "oficina", "aviadora"):
        d.rounded_rectangle((82,53,105,66), 2, fill=ink)
        d.line((85,56,101,56), accent, 3)
        d.line((86,62,97,62), thread)
    if style != "malha":
        for sign in (-1,1):
            d.line([(64+sign*14,94),(64+sign*37,83),(64+sign*42,84)], ink, 3)
            d.line([(64+sign*14,96),(64+sign*38,85)], thread)
    d.line((11,117,116,117), ink, 2)
    d.line((19,119,107,119), thread)

    d = ImageDraw.Draw(tiles[1])
    d.line([(2,41),(27,48),(96,48),(125,39)], ink, 2)
    d.line([(2,44),(27,51),(96,51),(125,42)], thread)
    if style == "piloto":
        d.rounded_rectangle((26,58,102,97), 4, fill=ink)
        d.text((64,69),"BAÍA DO SAL",fill=accent,font=font(10),anchor="mm")
        for k in range(3):
            x=43+k*19
            d.polygon([(x+2,76),(x+10,76),(x+7,89),(x-1,89)], fill=accent)
    elif style in ("colete","oficina"):
        d.arc((17,45,108,102),205,337,thread,2)
        d.text((64,75),"LITORAL",fill=thread,font=font(14),anchor="mm")

    d = ImageDraw.Draw(tiles[2])
    for y in (12,20,99,114):
        d.line([(0,y),(52,y+5),(128,y)], thread if y<99 else ink, 2)
    if style in ("piloto", "colete"):
        d.polygon([(13,3),(25,4),(27,98),(16,98)], fill=accent)
        d.line([(32,3),(34,98)], thread, 2)

    for index in (3,9):
        d = ImageDraw.Draw(tiles[index])
        d.line((11,0,11,128), deep, 3)
        d.line((15,0,15,128), palette(pants,1.25), 1)
        d.line([(6,28),(25,34),(43,25)], deep, 2)
        d.line([(7,30),(26,36),(44,27)], palette(pants,1.19), 1)
        d.line([(15,85),(45,80),(62,86)], palette(pants,1.14), 2)

    # Painted planes are aligned with the mesh's brow, nasolabial fold and chin.
    d = ImageDraw.Draw(tiles[4])
    shade = palette(skin,.80)
    cheek = palette(skin,1.075)
    brow = palette(hair,.92)
    d.polygon([(58,60),(64,49),(70,63),(69,72),(61,73)], fill=palette(skin,.91))
    for sign in (-1,1):
        c = 64+sign*25
        d.line([(c-11,50),(c,46),(c+9,49)],brow,3)
        d.polygon([(c-9,57),(c-3,53),(c+7,54),(c+10,57),(c+3,59),(c-5,59)],
                  fill=palette(skin,1.20))
        d.line([(c-9,57),(c-4,53),(c+6,54),(c+9,56)],palette(hair,.71),2)
        d.ellipse((c-3,54,c+3,59),fill=palette(hair,.66))
        d.point((c-1,54),palette(skin,1.29))
        d.polygon([(c-10,66),(c+8,62),(c+8,68),(c-1,72)],fill=cheek)
    d.line([(57,73),(61,75),(68,75),(72,73)],shade,2)
    d.line([(51,87),(60,85),(70,86),(76,84)],palette(skin,.65),2)
    d.line([(57,90),(68,90),(72,88)],cheek,2)
    if id in ["raul","dante","toni"]:
        d.arc((37,66,91,116),7,174,shade,6)
    if id in ["nia", "sol", "lia"]:
        for x,y in [(45,67),(50,64),(53,68),(58,67),(74,67),(78,66),(84,68)]:
            d.point((x,y),palette(skin,.75))

    d = ImageDraw.Draw(tiles[5])
    hair_high,hair_dark = palette(hair,1.27),palette(hair,.72)
    for x in range(-25,153,9):
        d.line([(x,0),(x+9,29),(x-4,65),(x+13,127)],hair_high,2)
        d.line([(x+3,1),(x+12,29),(x-1,65),(x+16,127)],hair_dark)
    d = ImageDraw.Draw(tiles[6])
    d.line([(1,108),(19,101),(106,101),(127,108)],leather,5)
    for y in range(38,81,10):
        d.line([(40,y+6),(61,y),(83,y+6)],palette(shoes,1.57),3)
    d.arc((16,8,112,96),6,173,palette(shoes,1.29),3)
    d = ImageDraw.Draw(tiles[7])
    for y in range(0,128,8):
        d.line((0,y,128,y),palette(liner,.89),2)
    d = ImageDraw.Draw(tiles[11])
    d.line((0,92,128,92),thread,3)
    d.line((0,97,128,97),ink,2)
    d.polygon([(51,44),(63,34),(76,44),(73,62),(52,62)],fill=ink)
    d.line([(54,54),(70,42)], accent,4)
    atlas(tiles,f"cast_{id}.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    for index,(id,spec) in enumerate(CAST.items()):
        paint(id,spec,index)
