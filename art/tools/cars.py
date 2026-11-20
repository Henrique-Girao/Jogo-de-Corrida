"""Build welded coachwork, recessed RIMs, and individual front and rear treatments."""
import math

import bpy

from car_profiles import CARS, STATIONS
from mesh_tools import ROOT, Mesh, atlas_uv, blend, collection, export, material, mix, sample, save, studio

TAU = math.tau
ATLAS = ROOT / "assets/models/cars/atlas"


def lines(spec):
    size, (radius, tire_depth), axles, _, _, deck, width, cabin, *_ = spec
    w, h, length = size
    a, b, c, d, roof_w, crown, pillar = cabin
    ar = radius + .045
    ground = .15 if h < 1.28 else .18
    for_fascia = [.022, .112, .885, .978]
    openings = []
    cuts = STATIONS + cabin[:4] + (pillar - .010, pillar + .010, .58, .685, .71)
    cuts = list(cuts) + for_fascia
    for start, end in [(a, b), (c, d)]:
        cuts += [mix(start, end, f) for f in (.085, .43, .70, .925)]
    for axle in axles:
        center = axle + .5
        angle = math.acos((ground - radius) / ar)
        opening = ar * math.sin(angle) / length
        cuts += [center - opening - .008, center + opening + .008]
        cuts += [center + math.sin(mix(-angle, angle, i / 10)) * ar / length for i in range(11)]
        openings.append((center, opening))
    ts = sorted(set(round(t, 5) for t in cuts if 0.0 <= t <= 1.0))
    frames = []
    for t in ts:
        z = (t - .5) * length
        y_floor = ground + .02 * (1.0 - math.sin(t * math.pi))
        for center, opening in openings:
            distance = abs(t - center) * length
            if abs(t - center) < opening + .000009:
                y_floor = max(y_floor, radius + math.sqrt(max(0, ar * ar - distance * distance)))
        f = sample(list(zip(STATIONS, width)), t)
        base = sample(list(zip(STATIONS, deck)), t)
        flare = max(0, y_floor - ground) / (radius * 2)
        half = w * .5 * f
        hood = base + spec[-1] * max(0, math.sin((t / a) * math.pi)) if t < a else base
        shoulder = max(base - .080, y_floor + .041)
        fender = max(base - .011, shoulder + .024)
        top = sample([(0, hood), (a, hood), (b, h - crown*.24), ((b+c)/2, h),
                      (c, h-crown*.20), (d, hood), (1, hood)], t)
        if t < a or t > d:
            top = hood
        canopy = sample([(0, .86), (a, .86), (b, roof_w), (c, roof_w*.94), (d, .82), (1, .82)], t)
        lift = max(top - base, 0)
        off = .014 * math.sin(math.pi * t)
        strip = [
            (0, top, z), (half*canopy*.57, top - crown*.16, z),
            (half*canopy*.89, top - crown*.56, z),
            (half*canopy, top - crown*.86, z),
            (half*(canopy*.93 + .858*.07), mix(top - crown*.86, base+.011, .075), z),
            (half*(canopy*.13 + .858*.87), mix(top - crown*.86, base+.011, .915), z),
            (half*.878, base+.009, z),
            (half*.954, fender, z),
            (half, shoulder, z),
            (half*(.986 + .012*flare), mix(shoulder, y_floor, .58), z),
            (half*(.947 + .04*flare) - off, y_floor+.018, z),
            (half*(.927 + .04*flare) - off, y_floor, z),
            (half*.71, y_floor+.004, z),
            (half*.64, ground+.013, z),
            (0.0, ground+.013, z),
        ]
        # The windshield rails flatten into the hood and into the rear deck.
        if lift < .018:
            strip[4] = (half*.774, mix(top, base, .72)+.013, z)
            strip[5] = (half*.832, base+.016, z)
        # The fender's inner corner covers the full swept shoulder of the tire.
        inside = w*.485 - tire_depth*.95
        if y_floor > ground:
            for column in range(1,9):
                x, y, z = strip[column]
                ramp = min(1., max(0., (x-inside+.132)/.110))
                strip[column] = (x, y + ramp * max(0., y_floor+.045-y), z)
        frames.append(strip)
    return ts, frames


def glass_face(t, k, cabin, cargo):
    a, b, c, d, _, _, pillar = cabin
    windscreen = mix(a,b,.085) < t < mix(a,b,.925)
    rear = not cargo and mix(c,d,.085) < t < mix(c,d,.925)
    if k < 2 and (windscreen or rear):
        return True
    if k != 4 or not mix(a,b,.43) < t < (pillar - .01 if cargo else mix(c,d,.70)):
        return False
    return not pillar - .010 <= t <= pillar + .010


def coachwork(shell, spec, cargo):
    (width, height, _), *_, cabin, _, _, _, _, _ = spec
    times, frames = lines(spec)
    for sign in (-1, 1):
        rows = [[(x * sign, y, z) for x, y, z in frame] for frame in frames]
        for i, (first, last) in enumerate(zip(rows, rows[1:])):
            t0, t1 = times[i:i+2]
            for k in range(len(first)-1):
                pts = [first[k], first[k+1], last[k+1], last[k]]
                ts = (t0, t0, t1, t1)
                if glass_face((t0+t1)*.5, k, cabin, cargo):
                    shell.face(pts, 2, atlas_uv(7, [(t, y/height) for t, (_, y, _) in zip(ts, pts)]))
                elif k >= 11:
                    shell.face(pts, 1, atlas_uv(12, [(t, abs(x) / width) for t, (x, _, _) in zip(ts, pts)]))
                elif k < 4:
                    shell.face(pts, 0, atlas_uv(1, [(t, x / width + .5) for t, (x, _, _) in zip(ts, pts)]))
                else:
                    shell.face(pts, 0, atlas_uv(0, [(t, y / height) for t, (_, y, _) in zip(ts, pts)]))
    for end in (0, -1):
        half = frames[end]
        loop = half[:14] + [(-x, y, z) for x, y, z in reversed(half[1:14])]
        center = (0., (half[0][1] + half[13][1]) * .5, half[0][2])
        for i, first in enumerate(loop):
            face = [first, loop[(i+1)%len(loop)], center]
            shell.face(face, 0, atlas_uv(2, [(x / width + .5, y / half[0][1]) for x, y, _ in face]), False)


def rounded(cx, cy, rx, ry, cut=.32):
    return [(cx-rx,cy-ry*(1-cut)), (cx-rx*(1-cut),cy-ry), (cx+rx*(1-cut),cy-ry),
            (cx+rx,cy-ry*(1-cut)), (cx+rx,cy+ry*(1-cut)), (cx+rx*(1-cut),cy+ry),
            (cx-rx*(1-cut),cy+ry), (cx-rx,cy+ry*(1-cut))]


def ellipse(x, y, sx, sy, points=14):
    return [(x + sx * math.cos(TAU * j / points), y + sy * math.sin(TAU * j / points))
            for j in range(points)]


def plate(mesh, shape, z, inset, border, slot, face_tile):
    mid = tuple(sum(p[i] for p in shape)/len(shape) for i in range(2))
    minimum = [min(p[i] for p in shape) for i in range(2)]
    span = [max(p[i] for p in shape) - minimum[i] for i in range(2)]
    direction = math.copysign(1.0, z)

    def rim(scale, offset):
        return [(*blend(mid, pt, scale), z + direction * offset) for pt in shape]

    bed = rim(1.0, -.002)
    lip = rim(1.0, .008)
    well = rim(inset, .005)
    uv = lambda i, j, pts: atlas_uv(border, [(.42, .44), (.59, .44), (.59, .53), (.42, .53)])
    def face_uv(points):
        return atlas_uv(face_tile, [((x-minimum[0])/span[0], (y-minimum[1])/span[1]) for x, y, _ in points])
    mesh.strip(bed, lip, 1, uv, False)
    mesh.strip(lip, well, 1, uv, False)
    mesh.face(well, slot, face_uv(well), False)
    mesh.face(list(reversed(bed)), 1, face_uv(bed), False)


def ends(mesh, spec):
    (width, _, length), _, _, _, _, deck, widths, _, front, rear, *_ = spec
    for n, type_ in enumerate((front, rear)):
        outward = 2 * n - 1
        z = length * .5 * outward + .009 * outward
        w = width * .5 * widths[-1 if n else 0]
        h = deck[-1 if n else 0]
        low = .195 if spec[0][1] >= 1.28 else .173
        def p(shape, slot, uv, border=14, bevel=.87, shift=0):
            xy = [(w*x, mix(low, h, y)) for x, y in shape]
            plate(mesh, xy, z + outward*shift, bevel, border, slot, uv)
        # The front and rear have independently cut lenses and negative-space intakes.
        if n == 0:
            grille = {
                "quad": (.40, .45, .23, 9), "sweep": (.46, .40, .21, 14),
                "bar": (.46, .51, .21, 9), "rally": (.32, .53, .25, 14),
                "pop": (.65, .31, .12, 14), "dual": (.44, .52, .27, 9),
                "oval": (.43, .40, .25, 9), "blade": (.37, .37, .22, 14),
                "intake": (.40, .34, .24, 14), "utility": (.51,.395,.208,14),
            }[type_]
            gx, gy, gr, bumper = grille
            p(ellipse(0, gy, gx, gr) if type_ == "oval" else rounded(0, gy, gx, gr), 1, 1, bumper)
            if type_ in {"sweep", "bar", "rally", "blade", "intake"}:
                p(rounded(0, .10, .68, .044), 1, 14, 0)
            for sign in (-1, 1):
                def lens(shape, uv=4, slot=3, border=14):
                    p([(sign*x, y) for x, y in shape], slot, uv, border)
                if type_ == "quad":
                    lens(rounded(.655, .58, .189, .170, .18), border=9)
                    lens(rounded(.664, .29, .137, .064), 5, 1)
                elif type_ == "dual":
                    for x, y, r in ((.57,.57,.112), (.793,.59,.10)):
                        lens(ellipse(x, y, r, r*1.48), border=9)
                elif type_ == "oval":
                    lens(ellipse(.732, .65, .143, .222), border=9)
                elif type_ == "utility":
                    lens(rounded(.65,.644,.228,.147,.18), border=14)
                    lens(rounded(.659,.428,.157,.053,.16), 5, 1)
                elif type_ == "pop":
                    lens(rounded(.642, .60, .248, .102, .15), 5, 1)
                elif type_ == "sweep":
                    lens([(.45,.54),(.785,.615),(.895,.835),(.81,.858),(.47,.703)])
                elif type_ == "intake":
                    lens([(.48,.61),(.86,.663),(.887,.832),(.822,.842),(.52,.747)])
                    lens([(.49,.15),(.775,.113),(.88,.462),(.65,.433)], 1, 1)
                elif type_ == "blade":
                    lens([(.46,.614),(.833,.625),(.89,.847),(.72,.811),(.45,.71)])
                    lens([(.52,.135),(.82,.145),(.89,.502),(.64,.4)], 1, 1)
                elif type_ == "rally":
                    lens([(.39,.57),(.739,.589),(.878,.736),(.86,.829),(.426,.749)])
                    lens([(.51,.17),(.791,.173),(.858,.36),(.548,.361)], 1, 1)
                else:
                    lens(rounded(.667,.69,.215,.105), border=9)
            p(rounded(0, .86, .056, .028), 1, 9)
        else:
            p(rounded(0,.48,.86,.276), 1, 7 if type_ == "oval" else 14, 9 if type_ in ("oval","stack") else 14)
            p(rounded(0,.431,.195,.135), 1, 13, 14, shift=.012)
            if type_ in ("lightbar", "arc"):
                outline = [(-.85,.671),(-.61,.612),(0,.578),(.61,.612),(.85,.671),(.85,.716),
                           (.61,.693),(0,.656),(-.61,.693),(-.85,.716)]
                if type_ == "lightbar":
                    outline = rounded(0,.677,.843,.059)
                p(outline, 4, 6, shift=.011)
            for sign in (-1, 1):
                def tail(shape, uv=6, slot=4):
                    p([(sign*x,y) for x,y in shape], slot, uv, shift=.012)
                if type_ == "round":
                    tail(ellipse(.485,.55,.131,.157))
                    tail(ellipse(.748,.55,.113,.148))
                elif type_ == "oval":
                    tail(ellipse(.713,.51,.140,.214))
                elif type_ == "stack":
                    tail(rounded(.566,.613,.231,.079))
                    tail(rounded(.566,.401,.231,.070), 5, 1)
                elif type_ == "angle":
                    tail([(.33,.55),(.70,.533),(.833,.654),(.80,.708),(.52,.631),(.34,.642)])
                elif type_ == "bar":
                    tail(rounded(.582,.548,.238,.111))
                tail(rounded(.62,.165,.116,.040), 9, 1)



def edge_uv(cell, size):
    return lambda i,j,p: atlas_uv(cell,[(i/size,.22),((i+1)/size,.22),((i+1)/size,.76),(i/size,.76)])

def appendages(mesh, spec, key):
    (w, _, length), *_ = spec
    a = spec[7][0]
    # Shells with a back lip for the door mirrors, tracked by the cowl station.
    z = (a + .066 - .5)*length
    y = sample(list(zip(STATIONS, spec[5])), a + .066)+.095
    for sign in (-1, 1):
        outline = [(0,.013),(.048,.065),(.141,.068),(.209,.036),
                   (.212,-.02),(.164,-.044),(.064,-.041),(0,-.017)]
        def edge(scale, tz):
            return [((w*.435+.102+(x-.102)*scale)*sign, y+dy*scale, z+tz) for x,dy in outline]
        back, mid, glass = edge(.73,-.071), edge(1,.028), edge(.83,.045)
        def project(pts,cell):
            return atlas_uv(cell,[((sign*x-w*.435)/.225,(py-y+.055)/.125) for x,py,_ in pts])
        mesh.strip(back, mid, 0, edge_uv(3,len(outline)))
        mesh.strip(mid, glass, 1, edge_uv(14,len(outline)))
        mesh.face(back, 0, project(back,3))
        mesh.face(glass, 1, project(glass,9), False)
        base = [(sign*w*.42, y-.071,z-.068),(sign*w*.49,y-.039,z-.048),
                (sign*w*.502,y-.017,z+.005),(sign*w*.42,y-.039,z+.047)]
        last = [(x+sign*.011,yy+.016,zz) for x,yy,zz in base]
        mesh.strip(base,last,1,edge_uv(14,len(base)))
        mesh.face(base,1,atlas_uv(14,[((sign*x-w*.40)/.13,(pz-z+.09)/.19) for x,_,pz in base]))
        mesh.face(last,1,atlas_uv(14,[((sign*x-w*.40)/.13,(pz-z+.09)/.19) for x,_,pz in last]))
    if key in ("iris_22", "vetra_x", "trovao_68"):
        tall = {"iris_22": .19, "vetra_x": .13, "trovao_68": .091}[key]
        tz = length * (.453 if key == "vetra_x" else .424)
        top = spec[5][-2] + tall + (.083 if key == "vetra_x" else .025)
        for sign in (-1,1):
            ring = [(sign*w*.32,top-tall-.04,tz-.11), (sign*w*.32,top-.02,tz-.043),
                    (sign*w*.32,top+.01,tz+.092),(sign*w*.32,top-tall-.025,tz+.049)]
            other = [(x+sign*.042,y,z) for x,y,z in ring]
            uv = atlas_uv(3,[((z-tz+.12)/.23,(y-top+tall+.05)/(tall+.08)) for _,y,z in ring])
            mesh.strip(ring,other,0,edge_uv(3,len(ring)),False)
            mesh.face(ring,0,uv,False)
            mesh.face(other,0,uv,False)
        blade = [(-w*.435,.009,-.041),(-w*.384,-.013,-.145),(w*.384,-.013,-.145),
                 (w*.435,.009,-.041),(w*.462,.027,.137),(-w*.462,.027,.137)]
        airfoil = [(x, top+y, tz+z) for x,y,z in blade]
        lower = [(x*.972, y-.028, z-.01) for x,y,z in airfoil]
        def plan(pts,cell):
            return atlas_uv(cell,[(x/w+.5,(z-tz+.17)/.32) for x,_,z in pts])
        mesh.face(airfoil,0,plan(airfoil,3))
        mesh.face(lower,1,plan(lower,14))
        mesh.strip(lower,airfoil,0,edge_uv(3,len(blade)),False)


def wheel_mesh(spec):
    (_, (r, depth), _, _, _, _, _, _, _, _, count, spoke_width, _) = spec
    m = Mesh()
    radial = 30 if count in (5, 6, 10) else 28
    rim_size = .73 if spec[0][1] > 1.31 else .795
    rim_size -= .05 if count == 4 else 0
    def circle(x, radius):
        return [(x*depth, math.sin(TAU*i/radial)*radius*r, math.cos(TAU*i/radial)*radius*r)
                for i in range(radial)]
    # Bead, bulged sidewall and non-square tread shoulder are part of one continuous tire profile.
    tire = [(-.47,rim_size),(-.498,.847),(-.488,.91),(-.425,.96),(-.31,.991),(-.204,1.0),
            (.206,1.0),(.321,.989),(.425,.958),(.491,.909),(.501,.835),(.473,rim_size),
            (.30,rim_size-.025),(-.29,rim_size-.025)]
    for k, (a,b) in enumerate(zip(tire, tire[1:]+tire[:1])):
        def uv(i,j,_p):
            u0, u1 = k/len(tire), (k+1)/len(tire)
            v0, v1 = i/radial, (i+1)/radial
            tile = 0 if 3 <= k <= 8 else 8
            return atlas_uv(tile, [(u0,v0),(u0,v1),(u1,v1),(u1,v0)])
        m.strip(circle(*a),circle(*b),0,uv)
    barrel = [(-.424,rim_size-.010),(.392,rim_size-.013),(.469,rim_size-.012),
              (.492,rim_size-.044),(.454,rim_size-.067),(.309,rim_size-.086),
              (-.41,rim_size-.085)]
    for k,(a,b) in enumerate(zip(barrel,barrel[1:]+barrel[:1])):
        def uv(i,j,_p):
            cell = 9 if 1 <= k <= 4 else 10
            return atlas_uv(cell, [(i/radial,.25),((i+1)/radial,.25),((i+1)/radial,.79),(i/radial,.79)])
        m.strip(circle(*a),circle(*b),0,uv)
    rotor = circle(.16,rim_size*.874)
    rotor_back = circle(.115,rim_size*.874)
    def planar(points, tile):
        return atlas_uv(tile, [(.5+y/(2*r),.5+z/(2*r)) for _,y,z in points])
    m.face(rotor,0,planar(rotor,3),False)
    m.face(rotor_back,0,planar(rotor_back,3),False)
    m.strip(rotor_back,rotor,0,lambda _i,_j,p: planar(p,10),False)
    for i in range(count):
        theta = TAU*i/count
        angles = [-spoke_width*.90,-spoke_width*.53,spoke_width*.52,spoke_width*.91,
                  spoke_width*.64,spoke_width*.68,-spoke_width*.73]
        lengths = [.207, rim_size*.90, rim_size*.943, rim_size*.90, rim_size*.66, .247, .207]
        twist = .16 if count == 7 else (-.10 if count in (8,10) else .048)
        outline = [(theta+alpha+twist*rad,rad) for alpha,rad in zip(angles,lengths)]
        def flap(x, scale=1.0):
            return [(depth*(x - .10*rad), math.sin(a)*(rad*r*scale), math.cos(a)*(rad*r*scale))
                    for a,rad in outline]
        back, lip, face = flap(.268), flap(.45), flap(.495,.987)
        m.strip(back,lip,0,lambda _i,_j,p: planar(p,10),False)
        m.strip(lip,face,0,lambda _i,_j,p: planar(p,9),False)
        m.face(face,0,planar(face,2),False)
        m.face(back,0,planar(back,10),False)
    a,b,c = circle(.17,.226),circle(.44,.226),circle(.53,.181)
    m.strip(a,b,0,lambda _i,_j,p: planar(p,10))
    m.strip(b,c,0,lambda _i,_j,p: planar(p,9))
    m.face(c,0,planar(c,2),False)
    m.face(a,0,planar(a,10),False)
    return m


def main():
    studio()
    trim = material("Acabamento", ATLAS / "coach_trim.png", .50, .17)
    glass = material("Vidro", ATLAS / "coach_trim.png", .27, .10)
    head = material("Farois", ATLAS / "coach_trim.png", .36, .0)
    tail = material("Lanternas", ATLAS / "coach_trim.png", .32, .0)
    alloy = material("Rodas", ATLAS / "coach_trim.png", .53, .27)
    bodies = []
    for i, (key, spec) in enumerate(CARS.items()):
        group = collection(key)
        paint = material("Pintura_"+key, ATLAS / f"finish_{key}.png", .27, .16)
        shell = Mesh()
        coachwork(shell,spec,key=="furgao_servico")
        ends(shell,spec)
        appendages(shell,spec,key)
        body = shell.build("Carroceria_"+key, (paint,trim,glass,head,tail), group)
        wheel = wheel_mesh(spec).build("Roda_"+key, (alloy,), group)
        export([body, wheel], f"assets/models/cars/{key}.glb")
        bodies.append(body)
        # The editable studio holds every assembled study beside its source wheel.
        x, y = (i % 5 - 2) * 3.85, (i // 5) * 6.0
        body.location = (x,y,0)
        w, _, length = spec[0]
        r, width = spec[1]
        wheel.location = (x+w*.485-width*.45, y-spec[2][0]*length, r)
        for axle, sign in ((spec[2][0],-1),(spec[2][1],1),(spec[2][1],-1)):
            copy = wheel.copy()
            group.objects.link(copy)
            copy.location = (x+sign*(w*.485-width*.45),y-axle*length,r)
            copy.rotation_euler.z = 0 if sign > 0 else math.pi
        srgb = [int(spec[3][j:j+2],16)/255 for j in (0,2,4)]
        tint = [c/12.92 if c < .04045 else ((c+.055)/1.055)**2.4 for c in srgb]+[1.]
        paint.diffuse_color = tint
        shader = paint.node_tree.nodes.get("Principled BSDF")
        base = shader.inputs["Base Color"]
        ink = paint.node_tree.nodes.new("ShaderNodeMixRGB")
        ink.blend_type = "MULTIPLY"
        ink.inputs[0].default_value = 1.
        ink.inputs[2].default_value = tint
        paint.node_tree.links.new(base.links[0].from_socket,ink.inputs[1])
        paint.node_tree.links.new(ink.outputs[0],base)
        print(f"{key}: {len(body.data.polygons)} body faces, {len(wheel.data.polygons)} wheel faces")
    save("carrocerias.blend", bodies[2])


if __name__ == "__main__":
    main()
