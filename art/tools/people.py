"""Tailored character topology with welded shoulder sockets and a shared skeleton."""
import math

import bpy

from cast_profiles import CAST
from mesh_tools import Mesh, atlas_uv, collection, export, material, mix, save, studio, vector

N = 16


def oval(y, rx, rz, cx=0., cz=0., shape=.9, count=N, phase=0):
    def curve(value):
        return math.copysign(abs(value)**shape, value)
    return [(cx+rx*curve(math.sin(phase+i*math.tau/count)), y,
             cz-rz*curve(math.cos(phase+i*math.tau/count))) for i in range(count)]


def distance(a,b):
    return sum((p-q)**2 for p,q in zip(a,b))


def rotate_to_fit(reference, ring):
    count=len(ring)
    return min(((start,sign) for start in range(count) for sign in (-1,1)),
               key=lambda pair: sum(distance(point,ring[(pair[0]+pair[1]*i)%count])
                                    for i,point in enumerate(reference)))


class Character:
    def __init__(self, id, spec):
        self.id = id
        self.mesh = Mesh()
        self.weights = {}
        self.spec = spec
        self.bones = {"Corpo": (None,(0,.956,.012),(0,1.408,.008)),
                      "Cabeca": ("Corpo",(0,1.515,0),(0,1.736,.002))}
        self.make_body()
        self.make_head()

    def weight(self, ring, *groups):
        for point in ring:
            self.weights[tuple(round(p,6) for p in point)] = groups

    def face(self, points, index, flatten, smooth=True):
        self.mesh.face(points, 0, atlas_uv(index, [flatten(*pt) for pt in points]), smooth)

    def rings(self, frames, index, flatten, smooth=True):
        for first, next_ in zip(frames,frames[1:]):
            self.mesh.strip(first,next_,0,lambda _i,_j,p:atlas_uv(index,[flatten(*pt) for pt in p]),smooth)

    def make_body(self):
        _, _, shoulder, hips, _, _, _, style, *_ = self.spec
        # A continuous garment surface with separate edge flow at waistband, rib cage and collar.
        layer = .008 if style in ("aviadora","oficina") else 0
        torso = [(.911,.159*hips,.101,.015),(.966,.174*hips,.105,.014),
                 (1.022,.158*hips,.109,.005),(1.148,.168*shoulder,.118,.007),
                 (1.250,.182*shoulder,.122+layer,.009),(1.349,.220*shoulder,.122+layer,.010),
                 (1.418,.213*shoulder,.114,.013),(1.470,.135*shoulder,.082,.015),
                 (1.494,.068,.060,.012),(1.528,.059,.061,.010)]
        frames = [oval(y,rx,rz,cz=z,shape=.76 if i<7 else .92)
                  for i,(y,rx,rz,z) in enumerate(torso)]
        for ring in frames:
            self.weight(ring,("Corpo",1.))
        self.weight(frames[-1],("Corpo",.15),("Cabeca",.85))

        def jacket(back):
            return lambda x,y,z:(.5+(.5 if back else -.5)*x/.227, (y-.946)/.554)

        for i,(a,b) in enumerate(zip(frames,frames[1:])):
            for j in range(N):
                if i in (4,5) and j in (3,4,11,12):
                    continue
                k = (j+1)%N
                pts = [a[j],a[k],b[k],b[j]]
                back = 4 <= j < 12
                index = 8 if i==8 else (3 if i==0 else int(back))
                self.face(pts,index,jacket(back))
        for sign in (1,-1):
            def mirror(i):
                return i if sign > 0 else (N-i)%N
            stitches = [(4,3),(4,4),(4,5),(5,5),(6,5),(6,4),(6,3),(5,3)]
            self.make_sleeve(sign,[frames[i][mirror(j)] for i,j in stitches],shoulder)
        crotch = [(0,.839,.068),(0,.827,.012),(0,.841,-.050)]
        self.weight(crotch,("Corpo",1.))
        self.make_leg(1,frames[0][:9]+crotch,hips)
        self.make_leg(-1,frames[0][8:]+frames[0][:1]+list(reversed(crotch)),hips)
        self.neck = frames[-1]

    def make_sleeve(self, sign, socket, shoulder):
        _,_,_,_,_,_,_,style,*_ = self.spec
        side = ".L" if sign>0 else ".R"
        arm, elbow = "Ombro"+side, "Cotovelo"+side
        self.bones[arm] = ("Corpo",(sign*.211*shoulder,1.374,.011),(sign*.281*shoulder,1.153,.014))
        self.bones[elbow] = (arm,(sign*.281*shoulder,1.153,.014),(sign*.306*shoulder,1.027,-.010))
        cut = .070 if style in ("oficina","colete") or self.id == "sol" else -.016
        wide = 1.02 if style=="aviadora" else (.93 if style=="piloto" else .95)
        rows = [
            (1.292,.246,.085,.091,.008,2,((arm,.71),("Corpo",.29))),
            (1.213,.270,.073,.077,.016,2,((arm,.90),(elbow,.10))),
            (1.153,.281,.068,.072,.014,2,((arm,.47),(elbow,.53))),
            (1.103+cut,.294,.060,.061,.003,2,((elbow,1.),)),
            (1.089+cut,.296,.055,.056,.001,7,((elbow,1.),)),
            (1.078+cut,.298,.044,.044,-.002,8,((elbow,1.),)),
            (1.031,.308,.043,.038,-.017,8,((elbow,1.),)),
            (.993,.309,.025,.029,-.026,8,((elbow,1.),)),
        ]
        start,order=0,1
        prev=socket
        for i,(y,cx,rx,rz,z,index,weights) in enumerate(rows):
            raw = oval(y,rx*wide,rz*wide,sign*cx*shoulder,z,count=len(socket))
            raw = [(x,y+(x-sign*cx*shoulder)*sign*.31,z) for x,y,z in raw]
            if i==0:
                start,order=rotate_to_fit(socket,raw)
            ring=[raw[(start+order*j)%len(raw)] for j in range(len(raw))]
            if index == 8:
                # Add the thumb pad on the inner edge before the finger tips taper.
                ring = [(x - sign * (.011 if i == 6 else .004),y,z-.008)
                        if sign*x < cx*shoulder and z < 0 else (x,y,z) for x,y,z in ring]
            self.weight(ring,*weights)
            if index == 2 and style == "colete":
                index = 7
            for j in range(len(ring)):
                k=(j+1)%len(ring)
                pts=[prev[j],prev[k],ring[k],ring[j]]
                self.face(pts,index,lambda x,y,z:(.5-z/.21,(y-.995)/.399))
            prev=ring
        self.face(prev,8,lambda x,y,z:(.45+x*.1,.48+z),False)

    def make_leg(self, sign, socket, hips):
        side=".L" if sign>0 else ".R"
        leg,knee,foot="Coxa"+side,"Joelho"+side,"Pe"+side
        cx = sign*.104*hips
        self.bones[leg]=("Corpo",(cx,.904,.013),(sign*.114*hips,.468,-.012))
        self.bones[knee]=(leg,(sign*.114*hips,.468,-.012),(sign*.119*hips,.137,.010))
        self.bones[foot]=(knee,(sign*.119*hips,.137,.010),(sign*.120*hips,.054,-.082))
        cuff=.006 if self.spec[7] in ("malha","colete") else 0.
        loose = 1.14 if self.spec[7] in ("oficina","malha") else .97
        data = [
            (.795,.105,.082*hips,.092,.014,3,((leg,.77),("Corpo",.23))),
            (.659,.109,.081*loose,.085,.014,3,((leg,1.),)),
            (.512,.113,.069*loose,.068,-.010,3,((leg,.86),(knee,.14))),
            (.460,.114,.066*loose,.067,-.014,3,((leg,.43),(knee,.57))),
            (.383,.116,.069*loose,.069,-.010,3,((leg,.11),(knee,.89))),
            (.223,.120,.052*loose,.059,.009,3,((knee,1.),)),
            (.143,.119,.047*loose,.053+cuff,.009,3,((knee,.76),(foot,.24))),
            (.117,.120,.050,.067,-.013,6,((foot,1.),)),
            (.077,.120,.060,.092,-.042,6,((foot,1.),)),
            (.036,.122,.064,.121,-.052,6,((foot,1.),)),
            (.019,.122,.062,.123,-.052,6,((foot,1.),)),
            (.003,.122,.060,.118,-.052,6,((foot,1.),)),
        ]
        prev=socket
        start,order=0,1
        for i,(y,x,rx,rz,z,index,w) in enumerate(data):
            raw=oval(y,rx,rz,sign*x*hips,z,shape=.68 if index==6 else .84,count=len(socket))
            if index==6:
                # The toe flares on the inner edge; the heel tapers independently.
                raw=[(px-sign*max(0.,z-pz)*.095,py,pz) for px,py,pz in raw]
            if i==0:
                start,order=rotate_to_fit(socket,raw)
            row=[raw[(start+order*j)%len(raw)] for j in range(len(raw))]
            self.weight(row,*w)
            for j in range(len(row)):
                k=(j+1)%len(row)
                pts=[prev[j],prev[k],row[k],row[j]]
                cell=9 if index==3 and sum(p[2] for p in pts)>.041 else index
                if index==6:
                    self.face(pts,cell,lambda x,y,z:(.5+(x-cx)/.144,(z+.18)/.26))
                else:
                    self.face(pts,cell,lambda x,y,z:(.5+(x-cx)*sign/.192,(y-.12)/.81))
            prev=row
        self.face(prev,6,lambda x,y,z:(.23,(z+.18)*.17+.08),False)

    def make_head(self):
        _,_,_,_,jaw,nose,cut,_,*_ = self.spec
        levels=[
            (1.535,.061,.058,-.004,.0),(1.555,.079*jaw,.077,-.006,.0),
            (1.584,.097*jaw,.085,-.003,.0),(1.616,.105,.096,.001,.024*nose),
            (1.632,.109,.099,.001,.028*nose),(1.659,.110,.099,.003,.006*nose),
            (1.684,.108,.097,.008,.0),(1.716,.097,.091,.011,.0),
            (1.747,.057,.059,.015,.0),
        ]
        ring=self.neck
        for index,(y,rx,rz,z,tip) in enumerate(levels):
            raw=oval(y,rx,rz,cz=z,shape=.80 if index in (1,2,3,4,5) else .92)
            nxt=[(x, yy, zz-tip*weight) for j,(x,yy,zz) in enumerate(raw)
                 for weight in [1.0 if j==0 else (.05 if j in (1,15) else 0.)]]
            self.weight(nxt,("Cabeca",1.))
            for j in range(N):
                k=(j+1)%N
                pts=[ring[j],ring[k],nxt[k],nxt[j]]
                if j in (0,1,2,13,14,15):
                    self.face(pts,4,lambda x,y,z:(.5-x/.215,(y-1.528)/.228))
                else:
                    self.face(pts,10,lambda x,y,z:((z+.10)/.22,(y-1.53)/.23))
            ring=nxt
        self.face(ring,10,lambda x,y,z:(.5+x,.88+z))
        # Ears have a folded pinna, with the outer edge rooted through the skin.
        for sign in (-1,1):
            loop=[(.095,1.608,.019),(.111,1.601,.006),(.126,1.627,-.004),
                  (.122,1.651,.001),(.110,1.657,.021),(.096,1.642,.030)]
            outer=[(sign*x,y,z) for x,y,z in loop]
            inner=[(sign*(.119 if i in (2,3) else .105),mix(y,1.633,.4),mix(z,.009,.5))
                   for i,(x,y,z) in enumerate(loop)]
            root=[(sign*(x-.023),y,z+.004) for x,y,z in loop]
            self.rings([root,outer,inner],10,lambda x,y,z:(.5+z*2,.5+(y-1.62)*4))
            self.face(inner,10,lambda x,y,z:(.47+z*2,.53+(y-1.62)*4))
            self.face(root,8,lambda x,y,z:(.5+x,.5+z))
            for r in (outer,inner,root):
                self.weight(r,("Cabeca",1.))
        self.make_hair(cut)

    def make_hair(self, cut):
        is_cap = cut.endswith("cap")
        breaks = {
            "bob":(1.675,1.574,1.598,.018), "swept":(1.676,1.641,1.625,.021),
            "knot":(1.687,1.672,1.633,.019), "coils":(1.685,1.652,1.627,.048),
            "ribbon":(1.674,1.665,1.644,.019), "locks":(1.676,1.521,1.516,.032),
            "parted":(1.699,1.664,1.638,.022), "high_knot":(1.693,1.671,1.646,.026),
            "fade":(1.698,1.675,1.651,.014), "wave":(1.673,1.584,1.541,.032),
            "shop_cap":(1.679,1.679,1.666,.030), "rally_cap":(1.682,1.674,1.660,.041),
            "driver_cap":(1.676,1.676,1.662,.031),
        }
        front,side,back,gain = breaks[cut]
        count=24
        def hairline(a):
            t=math.cos(a)
            return mix(side, front if t>=0 else back, t*t)+gain*.47*math.sin(a*2.5+.68)*max(0,t)
        def loop(rx,rz,f,visor=0):
            ring=[]
            for j in range(count):
                a=math.tau*j/count
                angle=math.cos(a)
                x=rx*math.sin(a)
                z=.013-rz*angle
                y=mix(hairline(a),1.762+gain,f)
                if is_cap and angle>.50:
                    extension=visor*(max(0,(angle-.50)/.50)**.47)
                    z-=extension
                    y-=extension*.11
                if cut=="coils":
                    x*=1+.065*math.sin(a*7+f*4)
                    z+=.007*math.sin(a*9+f*5)
                    y+=.008*math.sin(a*11+f*8)
                if cut in ("swept","wave","parted","locks"):
                    x+=gain*.57*f
                    z+=gain*.12*math.sin(a*3+f*4)
                ring.append((x,y,z))
            return ring
        if is_cap:
            length = .13 if cut=="rally_cap" else (.098 if cut=="driver_cap" else .081)
            rows=[loop(.102,.098,0.0),loop(.121,.123,.018,length*.90),
                  loop(.122,.124,.049,length),loop(.123,.121,.095,.012),
                  loop(.126,.118,.44),loop(.105,.102,.79),loop(.051,.052,1.0)]
        else:
            rows=[loop(.099,.087,-.04),loop(.117,.116,.027),loop(.123,.120,.21),
                  loop(.117,.110,.58),loop(.089,.090,.88),loop(.044,.051,1.0)]
        tile=11 if is_cap else 5
        for row in rows:
            self.weight(row,("Cabeca",1.))
        for i,(a,b) in enumerate(zip(rows,rows[1:])):
            self.mesh.strip(a,b,0,lambda j,k,p:atlas_uv(tile,[(j/count,i/len(rows)),((j+1)/count,i/len(rows)),
                                    ((j+1)/count,(i+1)/len(rows)),(j/count,(i+1)/len(rows))]))
        self.face(rows[-1],tile,lambda x,y,z:(.5+x,.92+z))
        self.face(rows[0],5,lambda x,y,z:(.5+x,.05+z*.2),False)
        if cut in ("knot","high_knot","ribbon"):
            y=1.742 if cut=="high_knot" else (1.688 if cut=="knot" else 1.661)
            loops=[oval(y+dy,rx,rz,cx=dx,cz=z,count=12) for dx,dy,z,rx,rz in
                   [(.029,-.044,.096,.041,.040),(.034,-.023,.123,.061,.053),
                    (.042,.004,.133,.066,.055),(.040,.044,.118,.047,.042),
                    (.034,.057,.108,.025,.025)]]
            self.rings(loops,5,lambda x,yy,z:(.5+x*3,(yy-y+.057)/.12))
            self.face(loops[0],5,lambda x,y,z:(.5+x,.15+z))
            self.face(loops[-1],5,lambda x,y,z:(.5+x,.75+z))
            for r in loops:
                self.weight(r,("Cabeca",1.))

    def build(self,index):
        folder=collection(self.id)
        h,width,*_=self.spec
        def scale(p):
            x,y,z=p
            return x*width,y*h,z
        points = list(self.mesh.points)
        self.mesh.points = [scale(point) for point in points]
        body = self.mesh.build("Malha_"+self.id,
                               [material("Tecido_"+self.id,f"cast_{self.id}.png",.80)],folder)
        rig = bpy.data.armatures.new("Ossos_"+self.id)
        skeleton = bpy.data.objects.new("Esqueleto_"+self.id,rig)
        folder.objects.link(skeleton)
        bpy.context.view_layer.objects.active = skeleton
        bpy.ops.object.mode_set(mode="EDIT")
        for name,(parent,start,end) in self.bones.items():
            bone=rig.edit_bones.new(name)
            bone.head=vector(scale(start))
            bone.tail=vector(scale(end))
            if parent:
                bone.parent=rig.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")
        body.parent=skeleton
        modifier=body.modifiers.new("Deformação","ARMATURE")
        modifier.object=skeleton
        groups={name:body.vertex_groups.new(name=name) for name in self.bones}
        for i,point in enumerate(points):
            for bone,portion in self.weights[tuple(round(p,6) for p in point)]:
                groups[bone].add([i],portion,"REPLACE")
        export([body,skeleton],f"assets/models/people/{self.id}.glb")
        skeleton.location = ((index%7-3)*1.15,(index//7)*2.3,0)
        print(f"{self.id}: {len(body.data.polygons)} faces, {len(self.bones)} bones")
        return body


def main():
    studio()
    subjects=[Character(id,profile).build(i) for i,(id,profile) in enumerate(CAST.items())]
    save("elenco.blend",subjects[0])


if __name__ == "__main__":
    main()
