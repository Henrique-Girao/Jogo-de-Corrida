"""Original finish atlas for the workshop, harbour and roadsides."""
from random import Random

from PIL import ImageDraw

from textures import OUT, atlas, font, grain


def main():
    colors = ["778587","404e54","b39b77","9ea5a0","acb3ae","77716a","767567","724f41",
              "667856","1a2832","c7c7aa","3b454a","282b30","84816d","fbdfaa","d1844c",
              "788887","8fadae","475868","b0b9b6","213541","6e7f84","b09272","947e64"]
    tiles = [grain(c,i,2.6,.17) for i,c in enumerate(colors)]
    rng=Random(603)
    d=ImageDraw.Draw(tiles[0])
    d.line((0,7,126,7),"#b8b9a7",2)
    d.text((12,30),"VIGÍLIA",fill="#c6c7b5",font=font(19))
    d.text((13,54),"PVS 6312",fill="#b3b7a8",font=font(11,True))
    d.text((86,93),"21 t",fill="#bfc1ae",font=font(12,True))
    d.line([(1,121),(33,117),(57,120),(79,113),(99,119),(127,116)],"#535d5b",2)
    for i in range(28):
        x, y = rng.randrange(128), rng.randrange(128)
        d.line((x,y,x+rng.randrange(2,9),y+1),"#828b82")
    d=ImageDraw.Draw(tiles[1])
    d.rectangle((1,1,126,126),outline="#718084",width=3)
    d.line((3,117,127,117),"#2b393e",4)
    d.line((5,8,121,8),"#7e8a85",1)
    for x in range(8,125,18):
        d.ellipse((x,12,x+2,14),fill="#a7af9e")
        d.ellipse((x,110,x+2,112),fill="#a7af9e")
    d=ImageDraw.Draw(tiles[2])
    for i in range(13):
        y=3+i*10
        a=rng.randrange(12)
        d.line([(0,y),(27+a,y-2),(47+a,y+2),(79+a,y),(127,y-2)],"#bda884",1)
        d.line([(0,y+1),(27+a,y),(49+a,y+4),(82+a,y+2),(127,y)],"#a38d6c",1)
    d.arc((48,37,71,54),0,340,"#987e5e",2)
    d.line((17,72,61,75),"#dbc5a2",1)
    d=ImageDraw.Draw(tiles[3])
    for y in range(5,127,12):
        for x in range(6,127,12):
            d.ellipse((x,y,x+3,y+3),fill="#66716c")
            d.point((x+1,y+3),fill="#ccd0ba")
    d=ImageDraw.Draw(tiles[4])
    d.rectangle((14,23,125,112),outline="#c1c6b5",width=2)
    d.line((18,92,125,92),"#717b75",6)
    d.text((25,49),"CARGA",fill="#666e67",font=font(19))
    d.text((25,68),"06 / B",fill="#6d7772",font=font(14,True))
    d=ImageDraw.Draw(tiles[5])
    d.rectangle((0,52,127,61),fill="#d7b092")
    d.rectangle((47,66,102,107),fill="#c1b297")
    d.text((74,79),"LUB",fill="#535251",font=font(12,True),anchor="mm")
    d.line((53,94,93,94),"#776d5f",2)
    for tile,main,low in [(6,"#8c8b80","#5e5f59"),(7,"#9b7057","#58443b"),(8,"#849069","#535a48")]:
        d=ImageDraw.Draw(tiles[tile])
        for i in range(32):
            x,y=rng.randrange(128),rng.randrange(128)
            end=(min(127,x+rng.randrange(4,17)),min(127,y+rng.randrange(1,6)))
            if tile==7:
                end=(min(127,x+rng.randrange(1,4)),min(127,y+rng.randrange(9,32)))
            d.line([(x,y),end],main if i%2 else low)
    d=ImageDraw.Draw(tiles[9])
    for y in range(17,115,10):
        d.line((5,y,125,y),"#253b48")
    d.polygon([(0,3),(104,3),(56,124),(0,124)],fill="#263844")
    d.line((17,108,76,108),"#38505a",2)
    d=ImageDraw.Draw(tiles[10])
    for x in range(5,128,13):
        d.line((x,0,x,128),"#a5a591")
    d=ImageDraw.Draw(tiles[11])
    for x in range(2,128,9):
        d.line((x,0,x+7,128),"#41494b",1)
    d=ImageDraw.Draw(tiles[12])
    for y in range(-10,140,20):
        d.line([(13,y),(44,y+6),(60,y+3),(105,y+8)],"#1a1f24",4)
        d.line([(14,y+4),(43,y+10),(59,y+7),(103,y+12)],"#4c5054")
    d=ImageDraw.Draw(tiles[13])
    d.rectangle((0,68,128,75),fill="#9d8760")
    d.line((0,67,128,67),"#cbc095",1)
    d.text((12,97),"RIBEIRA",fill="#b1a78a",font=font(17))
    d=ImageDraw.Draw(tiles[14])
    for i in range(3,128,6):
        d.line((i,0,i,127),"#c9bda4",1)
    d=ImageDraw.Draw(tiles[15])
    for x in range(-18,140,34):
        d.polygon([(x,0),(x+13,0),(x-12,128),(x-25,128)],fill="#383b3c")
    d=ImageDraw.Draw(tiles[16])
    for i in range(18):
        x=rng.randrange(9,125)
        y=rng.randrange(35,118)
        d.line((x,y,x+2,y+5),"#6b7777")
    d.rectangle((0,108,127,124),fill="#6f7b79")
    d.line((1,106,125,106),"#99a099",2)
    d=ImageDraw.Draw(tiles[17])
    d.arc((13,6,114,132),0,360,"#9ab1ad",2)
    d.arc((19,11,108,132),0,360,"#728b8b",1)
    d.line((27,105,103,107),"#aabdb5",2)
    d=ImageDraw.Draw(tiles[18])
    d.text((11,41),"VALÉRIA",fill="#9ca8a8",font=font(13))
    d.line((0,70,126,70),"#576570",1)
    d.line((0,98,126,98),"#344656",4)
    d=ImageDraw.Draw(tiles[19])
    d.line((0,26,126,26),"#8e9a9a",2)
    for i in range(13,126,26):
        d.rounded_rectangle((i,49,i+12,63),2,fill="#617a80")
    d=ImageDraw.Draw(tiles[20])
    d.polygon([(9,2),(58,1),(32,126),(5,124)],fill="#354952")
    for x in (4,27,49,73,95,121):
        d.line((x,0,x,128),"#6f7c7b",3)
    d.line((1,100,127,100),"#718283",4)
    d=ImageDraw.Draw(tiles[21])
    d.text((20,46),"ARMAZÉM",fill="#d9dbca",font=font(15))
    d.text((23,67),"CAIS • 06",fill="#bec1ae",font=font(11,True))
    d.line((12,71,110,71),"#89978f",2)
    d=ImageDraw.Draw(tiles[22])
    for y in (38,55,72,92,103,109):
        d.line([(1,y+8),(31,y+7),(43,y),(62,y+2),(89,y-5),(129,y-4)],"#9f8970",2)
    d=ImageDraw.Draw(tiles[23])
    for y in (15,38,72,84,104):
        d.line([(0,y),(36,y-3),(58,y+1),(103,y-7),(128,y-6)],"#85725d",2)
    atlas(tiles,"distritos.png",8,4)


if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    main()
