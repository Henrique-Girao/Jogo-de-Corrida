"""Low-poly studio for shaped hardware, folded sheet metal and natural scenery."""
import math

import bpy

from mesh_tools import Mesh, atlas_uv as uv_grid, blend, collection, export, material, mix, save, studio

TAU = math.tau


def atlas_uv(index, points):
    return uv_grid(index, points, 8, 4)


def corners(w, d, bevel, center=(0.,0.)):
    x,z=center
    return [(x-w+bevel,z-d),(x+w-bevel,z-d),(x+w,z-d+bevel),(x+w,z+d-bevel),
            (x+w-bevel,z+d),(x-w+bevel,z+d),(x-w,z+d-bevel),(x-w,z-d+bevel)]


def path_uv(cell, pts, coords):
    return atlas_uv(cell,[coords(*p) for p in pts])


def folded(m, profile, cells, scale, axis="y", slot=1):
    def point(a,b,v):
        return (a,v,b) if axis=="y" else (a,b,v)
    rows = [[point(a,b,v) for a,b in ring] for v,ring in profile]
    for i,(a,b) in enumerate(zip(rows,rows[1:])):
        m.strip(a,b,slot,lambda _j,_k,p:path_uv(cells[min(i,len(cells)-1)],p,scale),False)
    m.face(rows[0],slot,path_uv(cells[0],rows[0],scale),False)
    m.face(rows[-1],slot,path_uv(cells[-1],rows[-1],scale),False)


def front_panel(m, shape, start, end, out, face_cell, edge_cell=1, slot=1, inset=.94):
    middle=tuple(sum(p[k] for p in shape)/len(shape) for k in (0,1))
    rows=[[(x,y,start) for x,y in shape],[(x,y,end) for x,y in shape],
          [(*blend(middle,p,inset),out) for p in shape]]
    limits=[(min(p[k] for p in shape),max(p[k] for p in shape)) for k in (0,1)]
    def project(x,y,z):
        return ((x-limits[0][0])/(limits[0][1]-limits[0][0]),
                (y-limits[1][0])/(limits[1][1]-limits[1][0]))
    m.strip(rows[0],rows[1],slot,lambda _j,_k,p:path_uv(edge_cell,p,project),False)
    m.strip(rows[1],rows[2],slot,lambda _j,_k,p:path_uv(edge_cell,p,project),False)
    m.face(rows[-1],slot,path_uv(face_cell,rows[-1],project),False)
    m.face(rows[0],slot,path_uv(edge_cell,rows[0],project),False)


def turned_panel(mesh, axes, *args):
    panel=Mesh()
    front_panel(panel, *args)
    for indices, slot, uv, smooth in panel.polys:
        mesh.face([axes(*panel.points[i]) for i in indices],slot,uv,smooth)


def lathe(profile, tile, segments=24, loop=False, slot=1):
    m=Mesh()
    def ring(rad,y):
        return [(math.cos(j*TAU/segments)*rad,y,math.sin(j*TAU/segments)*rad)
                for j in range(segments)]
    spans=profile[1:]+profile[:1] if loop else profile[1:]
    for k,((rad,a),(rr,b)) in enumerate(zip(profile,spans)):
        def uv(j,idx,p):
            k0,k1=j/segments,(j+1)/segments
            if loop:
                v0,v1=k/len(profile),(k+1)/len(profile)
            else:
                v0,v1=a/profile[-1][1],b/profile[-1][1]
            return atlas_uv(tile(k),[(k0,v0),(k1,v0),(k1,v1),(k0,v1)])
        m.strip(ring(rad,a),ring(rr,b),slot,uv,True)
    if not loop:
        for k in (0,-1):
            rad,y=profile[k]
            pts=ring(rad,y)
            m.face(pts,slot,atlas_uv(tile(len(profile)),[(x/rad*.5+.5,z/rad*.5+.5) for x,_,z in pts]),False)
    return m


def terminal():
    m=Mesh()
    # Bent pedestal widenings have a clear setback for shoes and a broad mounting foot.
    stem=[(0.0,corners(1.105,.427,.126)),(.053,corners(1.105,.427,.126)),
          (.11,corners(.87,.368,.095)),(.147,corners(.385,.301,.083)),
          (.268,corners(.265,.239,.057,(0,-.051))),(.845,corners(.255,.189,.048,(0,-.074))),
          (1.095,corners(.327,.133,.052,(0,-.171))),(1.49,corners(.401,.123,.052,(0,-.166)))]
    folded(m,stem,[11,1,11,11,1,1],lambda x,y,z:(.5+x/2.22,y/1.5))
    bezel=corners(1.314,.414,.092,(0,1.423))
    rear=corners(1.16,.378,.085,(0,1.437))
    screen=corners(1.222,.361,.033,(0,1.423))
    hl=[(x,y,.143) for x,y in bezel]
    inset=[(x,y,.117) for x,y in screen]
    backs=[(x,y,-.238) for x,y in rear]
    uv=lambda cell,p:path_uv(cell,p,lambda x,y,z:(.5+x/2.65,(y-1.)/.85))
    m.strip(backs,hl,1,lambda _i,_j,p:uv(1,p),False)
    m.strip(hl,inset,1,lambda _i,_j,p:uv(11,p),False)
    m.face(backs,1,uv(11,backs),False)
    m.face(inset,1,uv(9,inset),False)
    return m


def workbench():
    m=Mesh()
    cap=[(.824,corners(1.78,.332,.070)),(.875,corners(1.855,.368,.049)),
         (.937,corners(1.876,.375,.048)),(.978,corners(1.832,.354,.047))]
    folded(m,cap,[11,2,2,2],lambda x,y,z:(.5+x/3.75,.5+z/.76))
    # Drawer carcase with a shallow kick space and separate lip around the front.
    folded(m,[(.047,corners(.69,.265,.057,(-.831,-.016))),
              (.106,corners(.76,.281,.064,(-.831,-.016))),
              (.798,corners(.764,.291,.053,(-.831,-.015))),
              (.852,corners(.748,.279,.062,(-.831,-.015)))],
           [11,1,11],lambda x,y,z:(.5+(x+.831)/1.54,y/.87))
    for j in range(3):
        y=.235+j*.201
        front_panel(m,corners(.660,.088,.022,(-.827,y)),.264,.307,.313,1)
        # Roll-formed latch, open behind the pull.
        grip=[(-1.117,y+.023,.309),(-1.10,y+.052,.325),(-1.058,y+.057,.353),
              (-.611,y+.057,.353),(-.561,y+.047,.329),(-.547,y+.024,.309)]
        thin=[(x,y-.024,z) for x,y,z in grip]
        shoulder=[(x,y-.017,z+.010) for x,y,z in grip]
        for i in range(len(grip)-1):
            m.face([grip[i],grip[i+1],shoulder[i+1],shoulder[i]],1,atlas_uv(10,[(.3,.8),(.7,.8),(.7,.7),(.3,.7)]),False)
            m.face([shoulder[i],shoulder[i+1],thin[i+1],thin[i]],1,atlas_uv(11,[(.3,.8),(.7,.8),(.7,.7),(.3,.7)]),False)
    # One bent trestle frame with a real opening for the mechanic's legs.
    outline=[(-.30,.0),(-.318,.08),(-.295,.748),(-.22,.846),(.214,.846),(.29,.77),
             (.323,.076),(.31,.0),(.207,.0),(.192,.114),(.172,.643),(.115,.718),
             (-.120,.716),(-.187,.63),(-.209,.092),(-.218,.0)]
    turned_panel(m,lambda z,y,x:(x,y,z),outline,1.402,1.514,1.548,1,11,1,.985)
    folded(m,[(.117,corners(.89,.057,.023,(.430,-.229))),(.155,corners(.96,.059,.024,(.416,-.226))),
              (.210,corners(.89,.055,.022,(.430,-.229)))],[1,11],lambda x,y,z:(.5+x/4.,.5+y))
    return m


def tool_board():
    m=Mesh()
    front_panel(m,corners(2.05,.725,.068),-.075,.052,.066,3)
    for k in range(5):
        x=-1.32+k*.572
        y=.235+.03*math.sin(k*1.17)
        stem=.30+k*.043
        scale=.76+k*.085
        shape=[(-.055,.12),(-.087,.086),(-.091,.035),(-.058,-.015),
               (-.022,-.060),(-.022,-stem),(-.001,-stem-.025),(.026,-stem),
               (.026,-.052),(.064,-.021),(.093,.026),(.078,.100),
               (.047,.118),(.039,.051),(.014,.031),(-.025,.039)]
        front_panel(m,[(x+u*scale,y+v*scale) for u,v in shape],.062,.085,.102,10,11,1,.982)
    return m


def shutter():
    m=Mesh()
    steps=[(0.02,-.091),(.07,-.061)]
    for i in range(13):
        y=.085+i*.224
        steps += [(y,-.012),(y+.037,.054),(y+.166,.054),(y+.205,.011)]
    steps += [(3.032,-.012),(3.076,-.065),(3.101,-.088)]
    for (a,za),(b,zb) in zip(steps,steps[1:]):
        for l,r in zip([-2.778,-2.69,2.69],[-2.69,2.69,2.778]):
            pts=[(l,a,za),(r,a,za),(r,b,zb),(l,b,zb)]
            m.face(pts,1,path_uv(13,pts,lambda x,y,z:(.5+x/5.56,y/3.1)),False)
    for sign in (-1,1):
        front_panel(m,[(sign*x,y) for x,y in [(2.71,0),(2.89,0),(2.95,.05),(2.95,3.18),
                                             (2.89,3.23),(2.71,3.19),(2.72,2.95)]],
                    -.13,.068,.09,11,1)
    front_panel(m,corners(2.958,.091,.042,(0,3.143)),-.134,.10,.124,1)
    return m


def container():
    m=Mesh()
    xs=[(-.5,0.),(-.477,0.)]
    for i in range(22):
        x=-.462+i*.042
        xs += [(x,-.013),(x+.009,.004),(x+.029,.004),(x+.038,-.013)]
    xs += [(.478,0.),(.5,0.)]
    ys=[(0.,-.011),(.056,.0),(.091,-.013),(.913,-.013),(.944,.0),(1.,-.011)]
    rows=[]
    for i,(y,offset) in enumerate(ys):
        use_ribs = i in (2,3)
        strip=[(x,y,-.495-rib if use_ribs else -.50-offset) for x,rib in xs]
        rows.append(strip+[(x,y,-z) for x,y,z in reversed(strip)])
    for level,(a,b) in enumerate(zip(rows,rows[1:])):
        for j in range(len(a)):
            k=(j+1)%len(a)
            pts=[a[j],a[k],b[k],b[j]]
            if j in (len(xs)-1,len(a)-1):
                uv=path_uv(1,pts,lambda x,y,z:(z+.5,y))
            else:
                uv=path_uv(0 if level==2 else 1,pts,lambda x,y,z:(1-x-.5 if z<0 else x+.5,y))
            m.face(pts,0,uv,False)
    for y in (rows[0],rows[-1]):
        m.face(y,0,path_uv(1,y,lambda x,y,z:(x+.5,z+.5)),False)
    for sign_x in (-1,1):
        # Each door has a crimped perimeter and its own locking rods and retaining strap.
        def facing(z,y,x):
            return (sign_x*x,y,z)
        for sign_z in (-1,1):
            turned_panel(m,facing,[(sign_z*z,y) for z,y in
                         [(.016,.119),(.443,.118),(.453,.151),(.453,.859),(.425,.899),(.017,.9)]],
                         .494,.502,.505,1,11,0,.965)
            for pos in (.18,.345):
                turned_panel(m,facing,corners(.012,.385,.006,(pos*sign_z,.508)),.502,.513,.516,10,11)
            turned_panel(m,facing,corners(.083,.019,.01,(.190*sign_z,.492)),.506,.516,.521,10,11)
    return m


def drum():
    rings=[(.299,0),(.324,.016),(.336,.036),(.333,.055),(.315,.073),
           (.315,.196),(.336,.212),(.337,.229),(.314,.246),(.319,.438),
           (.340,.459),(.340,.478),(.317,.490),(.314,.639),(.337,.660),
           (.352,.680),(.354,.702),(.343,.721),(.315,.721),(.306,.701)]
    # The lid's rolled rim overhangs the recessed steel top.
    return lathe(rings,lambda i:5 if i in (4,5,8,9,12,13) else 11,24)


def crate():
    m=Mesh()
    f=[(0,corners(.460,.454,.036)),(.033,corners(.48,.473,.04)),
       (.114,corners(.488,.49,.045)),(.181,corners(.449,.455,.038)),
       (.841,corners(.452,.467,.033)),(.887,corners(.488,.49,.047)),
       (.958,corners(.5,.498,.048)),(1.,corners(.465,.468,.047))]
    folded(m,f,[11,1,11,4,11,1,1],lambda x,y,z:(.5+x,y),slot=0)
    return m


def spare():
    return lathe([(.228,-.092),(.294,-.113),(.346,-.105),(.376,-.081),(.391,-.057),
                  (.399,-.032),(.399,.035),(.391,.062),(.378,.090),(.349,.106),(.294,.109),
                  (.226,.090),(.217,.072),(.217,-.066)],
                 lambda i:12,28,True)


def luminaire():
    m=Mesh()
    outer=corners(1.749,.196,.084)
    lens=corners(1.561,.116,.090)
    a=[(x,.065,z) for x,z in corners(1.682,.163,.082)]
    b=[(x,.028,z) for x,z in outer]
    c=[(x,-.043,z) for x,z in corners(1.716,.174,.071)]
    d=[(x,-.049,z) for x,z in lens]
    e=[(x*.992,-.078,z*.93) for x,z in lens]
    def uv(cell,p):
        return path_uv(cell,p,lambda x,y,z:(.5+x/3.50,.5+z/.39))
    for left,right,slot,cell in [(a,b,1,1),(b,c,1,11),(c,d,1,1),(d,e,2,14)]:
        m.strip(left,right,slot,lambda _j,_k,p:uv(cell,p),False)
    m.face(a,1,uv(11,a),False)
    m.face(e,2,uv(14,e),False)
    return m


def pole():
    m=Mesh()
    rings=[(0.,.129,.147,0.),(.047,.133,.145,0.),(.092,.117,.127,0.),(.257,.073,.076,0.),
           (.350,.055,.057,0.),(3.91,.049,.054,0.),(4.222,.050,.058,.038),(4.481,.048,.061,.142),
           (4.669,.052,.066,.301),(4.754,.051,.065,.475),(4.780,.05,.057,.644)]
    folded(m,[(y,corners(w,d,min(w,d)*.37,(0,z))) for y,w,d,z in rings],[11,1,11],
           lambda x,y,z:(x*.6+.5,y/4.85))
    h=[(4.653,corners(.113,.205,.08,(0,.640))),(4.697,corners(.162,.255,.103,(0,.638))),
       (4.777,corners(.167,.249,.103,(0,.625))),(4.812,corners(.122,.172,.072,(0,.585)))]
    folded(m,h,[11,1,11],lambda x,y,z:(.5+x/.33,.5+(z-.63)/.5))
    inner=[(x,4.642,z) for x,z in corners(.101,.169,.063,(0,.65))]
    border=[(x,4.656,z) for x,z in corners(.112,.182,.061,(0,.649))]
    m.strip(border,inner,1,lambda _j,_k,p:path_uv(11,p,lambda x,y,z:(.6,.6)),False)
    m.face(inner,2,path_uv(14,inner,lambda x,y,z:(.5+x/.205,.5+(z-.65)/.35)),False)
    return m


def bollard():
    return lathe([(.10,0.),(.125,.024),(.125,.052),(.104,.071),(.084,.408),
                  (.078,.697),(.079,.799),(.073,.85),(.049,.881)],
                 lambda i:15 if i in (5,6,7) else 11,12,False,0)


def escarpment(high=False, seed=0):
    m=Mesh()
    outline=[(-.48,-.14),(-.36,-.42),(-.115,-.49),(.164,-.42),(.34,-.38),(.49,-.046),
             (.410,.265),(.307,.405),(.057,.484),(-.16,.431),(-.42,.307),(-.49,.16)]
    if seed == 1:
        outline=[(-.487,-.16),(-.46,-.31),(-.322,-.465),(-.028,-.413),(.325,-.436),(.499,-.253),
                 (.420,.077),(.449,.331),(.144,.398),(-.013,.49),(-.33,.298),(-.49,.171)]
    count=len(outline)
    cell = 23 if seed == 1 else (22 if high else 6)
    g=[(-.50,.87,.02,.012),(-.318,1.0,0.,0.),(-.164,.985,-.021,.023),(.065,.81,-.051,.014),
       (.258,.69,-.089,-.019),(.405,.44,-.12,-.028),(.50,.12,-.154,.007)]
    if not high:
        g=g[:-2]+[(.378,.52,-.083,.010),(.50,.26,-.113,.027)]
    rows=[]
    for k,(y,scale,dx,dz) in enumerate(g):
        ring=[]
        for i,(x,z) in enumerate(outline):
            a=i*2.61+seed*1.091
            wiggle = (.043 if high else .060)*math.sin(a+k*1.28)
            ring.append((x*(scale+wiggle)+dx,
                         y+(.0 if k in (0,len(g)-1) else .045*math.cos(a+k*.63)),
                         z*(scale+wiggle*.92)+dz))
        rows.append(ring)
    for level,(a,b) in enumerate(zip(rows,rows[1:])):
        for i in range(count):
            j=(i+1)%count
            faces=([a[i],a[j],b[j]],[a[i],b[j],b[i]]) if (i+level)%3!=1 else ([a[i],a[j],b[j],b[i]],)
            for sub in faces:
                m.face(sub,0,path_uv(cell,sub,lambda x,y,z:(.5+x*.6+z*.3,y+.5)),False)
    m.face(rows[0],0,path_uv(cell,rows[0],lambda x,y,z:(x+.5,z+.5)),False)
    m.face(rows[-1],0,path_uv(cell,rows[-1],lambda x,y,z:(x+.5,z+.5)),False)
    return m


def tree(variant):
    m=Mesh()
    def branch(controls, radials):
        rows=[]
        for i,(x,y,z,r) in enumerate(controls):
            rows.append([(x+math.cos(TAU*j/radials+i*.11)*r,y,
                          z+math.sin(TAU*j/radials+i*.11)*r*.91) for j in range(radials)])
        def uv(j,k,p):
            a,b=j/radials,(j+1)/radials
            return atlas_uv(7,[(a,p[0][1]),(b,p[1][1]),(b,p[2][1]),(a,p[3][1])])
        for a,b in zip(rows,rows[1:]):
            m.strip(a,b,1,uv,False)
        for ring in (rows[0],rows[-1]):
            m.face(ring,1,path_uv(7,ring,lambda x,y,z:(x+.5,z+.5)),False)
    branch([(0,0,0,.057),(-.004,.051,.005,.041),(.009,.206,.00,.025),
            (.022,.404,.013,.021),(.039,.579,-.013,.015),(.055,.81,-.03,.004)],7)
    branches=[((.027,.395,0),(.102,.518,.047),(.190,.640,.099)),
              ((.023,.447,.004),(-.095,.554,-.036),(-.181,.718,-.08)),
              ((.041,.549,-.014),(.082,.656,-.089),(.120,.774,-.161))]
    if variant==1:
        branches=[((0,.346,0),(.056,.491,-.098),(.143,.621,-.185)),
                  ((.021,.413,0),(-.098,.556,.040),(-.198,.644,.09)),
                  ((.037,.548,0),(.077,.669,.079),(.151,.729,.151))]
    for start,mid,end in branches:
        branch([(*start,.025),(*mid,.014),(*end,.005)],5)
    def crown(center, radii, phase):
        x,y,z=center
        rx,ry,rz=radii
        sides=9
        rings=[]
        for k,(level,scale,dx) in enumerate([(-.65,.47,-.12),(-.283,.89,.015),(.095,1.,.041),
                                              (.477,.78,-.02),(.762,.49,-.07),(.92,.163,.10)]):
            ring=[]
            for i in range(sides):
                a=i*TAU/sides+phase+(k%2)*.094
                contour=1+.13*math.cos(i*7.3+phase*(k+.75))
                ring.append((x+rx*(dx+math.cos(a)*scale*contour),
                             y+ry*(level+.088*math.sin(i*3.09+k)),
                             z+rz*(math.sin(a)*scale*contour+
                                  .09*math.cos(k*2.+phase))))
            rings.append(ring)
        for i,(a,b) in enumerate(zip(rings,rings[1:])):
            def uv(j,k,p):
                return atlas_uv(8,[(j/sides,i/6),((j+1)/sides,i/6),((j+1)/sides,(i+1)/6),(j/sides,(i+1)/6)])
            for j in range(sides):
                k=(j+1)%sides
                us=uv(j,k,0)
                m.face([a[j],a[k],b[k]],0,us[:3],False)
                m.face([a[j],b[k],b[j]],0,[us[0],us[2],us[3]],False)
        for ring in (rings[0],rings[-1]):
            m.face(ring,0,path_uv(8,ring,lambda x,y,z:(x+.5,z+.5)),False)
    crown((.031,.743,-.01),(.223,.269,.220),.35+variant*.53)
    for i,(_,_,(x,y,z)) in enumerate(branches):
        crown((x,y+.046,z),(.138+i*.012,.196-i*.019,.158-i*.006),i*.71+variant*.40)
    return m



def seat():
    m=Mesh()
    # The tapered seat pan flows into the perforation-free curved backrest.
    widths=[.34,.388,.379,.363,.352,.341,.317,.294]
    path=[(.047,.252),(.063,.209),(.053,.094),(.073,-.057),(.152,-.113),(.258,-.154),
          (.367,-.189),(.411,-.201)]
    cols=[-1.,-.862,-.631,0.,.631,.862,1.]
    face=[]
    back=[]
    for k,(width,(y,z)) in enumerate(zip(widths,path)):
        for i,c in enumerate(cols):
            lip=abs(c)**3 * (.060 if k<4 else .018)
            face.append((c*width,y+lip,z+abs(c)*(.018 if k<4 else .038)))
            back.append((c*(width-.011),y+lip-.026,z+abs(c)*.026-.027))
    n=len(cols)
    def uv(points):
        return path_uv(17,points,lambda x,y,z:(x*.85+.51,.12+y*1.84))
    for k in range(len(path)-1):
        a,b=k*n,(k+1)*n
        for i in range(n-1):
            idx=[a+i,a+i+1,b+i+1,b+i]
            for layer in (face,back):
                pts=[layer[j] for j in idx]
                m.face(pts,0,uv(pts))
        for i in (0,n-1):
            pts=[face[a+i],face[b+i],back[b+i],back[a+i]]
            m.face(pts,0,uv(pts))
    for k in (0,len(path)-1):
        a=k*n
        m.strip(face[a:a+n],back[a:a+n],0,lambda _j,_k,p:uv(p),True,False)
    for x in (-.231,.231):
        bracket=[(-.201,0.),(.166,0.),(.174,.036),(.116,.059),
                 (-.119,.107),(-.164,.079),(-.195,.031)]
        turned_panel(m,lambda z,y,sx:(sx,y,z),bracket,x-.032,x+.025,x+.037,11,1,1,.985)
    return m


def warehouse():
    m=Mesh()
    doors=[(-.332,-.183),(-.075,.075),(.183,.332)]
    z_points=[-.50,-.481,.481,.50]
    for i in range(40):
        center=(i/40.-.5)*.956
        z_points.extend([center,center+.005,center+.012,center+.018])
    z_points=sorted(set(z_points+[z for pair in doors for z in pair]))
    levels=[.0,.041,.516,.564,.645,.799,.855]
    for sign in (-1,1):
        def rib(z):
            fraction=((z/.956+.5)*40)%1
            return .477 - (.011 if .175 < fraction < .56 and abs(z)<.477 else 0)
        for i,(a,b) in enumerate(zip(z_points,z_points[1:])):
            middle=(a+b)*.50
            loading=any(lo<=middle<=hi for lo,hi in doors)
            for row,(low,high) in enumerate(zip(levels,levels[1:])):
                if loading and row in (1,4):
                    continue
                pts=[(sign*rib(a),low,a),(sign*rib(b),low,b),
                     (sign*rib(b),high,b),(sign*rib(a),high,a)]
                cell=11 if row in (0,2) else 16
                m.face(pts,0,path_uv(cell,pts,lambda x,y,z:(z+.5, y)),False)
        def facing(z,y,x):
            return (sign*x,y,z)
        for left,right in doors:
            center=(left+right)*.5
            for i in range(10):
                y=.044+i*.047
                outline=corners((right-left)/2,.022,.004,(center,y+.022))
                turned_panel(m,facing,outline,.452,.467,.469,13,11,1,.991)
            for y in (.516,.8):
                turned_panel(m,facing,corners((right-left)*.52,.014,.005,(center,y)),.461,.481,.487,11,1)
            for frac in (-.030,.030):
                turned_panel(m,facing,corners(.043,.068,.004,(center+frac,.720)),
                             .454,.468,.475,9,11)
        for z in [-.484,-.357,-.124,.124,.357,.484]:
            turned_panel(m,facing,corners(.011,.425,.007,(z,.428)),.463,.487,.492,1,11,1)
    wall=[(-.477,0),(.477,0),(.477,.854),(.355,.886),(0,.979),
          (-.355,.886),(-.477,.854)]
    for sign in (-1,1):
        pts=[(x,y,sign*.50) for x,y in wall]
        m.face(pts,0,path_uv(21,pts,lambda x,y,z:(x+.5,y)),False)
    roof=[(-.497,.846),(-.50,.871),(-.386,.891),(0,1.),
          (.386,.891),(.50,.871),(.497,.846),(.389,.868),(0,.977),(-.389,.868)]
    a,b=[(x,y,-.50) for x,y in roof],[(x,y,.50) for x,y in roof]
    m.strip(a,b,1,lambda _j,_k,p: path_uv(1,p,lambda x,y,z:(z+.5,x+.5)),False)
    for pts in (a,b):
        m.face(pts,1,path_uv(11,pts,lambda x,y,z:(x+.5,y)),False)
    return m


def freighter():
    m=Mesh()
    # Cross sections follow a plumb bow, a flared sheer line and an almost square transom.
    stations=[(-.498,.012,.043),(-.451,.135,.035),(-.371,.290,.025),(-.255,.406,.010),
              (-.14,.474,.0),(.027,.499,.0),(.214,.496,.0),(.362,.446,.006),(.456,.368,.011),
              (.491,.327,.013)]
    def section(z,w,flare):
        right=[(0,.004+flare,z),(.46*w,.022+flare,z),(.72*w,.072+flare,z),
               (.91*w,.136+flare,z),(.944*w,.170+flare,z),(w,.207+flare,z),
               (w*.992,.296+flare,z),(w*.992,.344+flare,z),(.976*w,.361+flare,z),
               (w*.924,.369+flare,z),(w*.899,.338+flare,z),(0,.337+flare,z)]
        return right+ [(-x,y,z) for x,y,z in reversed(right[1:-1])]
    frames=[section(*s) for s in stations]
    spans=len(frames[0])
    for a,b in zip(frames,frames[1:]):
        for i in range(spans):
            j=(i+1)%spans
            pts=[a[i],a[j],b[j],b[i]]
            band=min(i,spans-1-i)
            color=15 if band in (3,4) else (11 if band<3 else 18 if band<9 else 2)
            m.face(pts,1,path_uv(color,pts,lambda x,y,z:(z+.5,min(.935,y*2.25))),band<4)
    for ring in [frames[0],frames[-1]]:
        m.face(ring,1,path_uv(1,ring,lambda x,y,z:(x+.5,y)),False)
    house=[(.327,corners(.221,.084,.031,(-.045,-.270))),(.374,corners(.234,.087,.039,(-.045,-.270))),
           (.437,corners(.217,.078,.037,(-.045,-.270))),(.596,corners(.214,.079,.038,(-.045,-.275))),
           (.682,corners(.207,.083,.038,(-.045,-.278))),(.779,corners(.196,.088,.042,(-.045,-.280))),
           (.801,corners(.209,.092,.039,(-.045,-.280))),(.887,corners(.218,.089,.041,(-.042,-.281))),
           (.928,corners(.227,.093,.036,(-.041,-.282))),(.960,corners(.209,.081,.038,(-.041,-.283)))]
    folded(m,house,[1,19,19,1,19,1,20,1,19],lambda x,y,z:(.5+x+z*.72,y))
    stack=[(.956,corners(.064,.024,.013,(-.082,-.252))), (1.060,corners(.052,.022,.011,(-.089,-.242))),
           (1.081,corners(.059,.026,.01,(-.091,-.239))), (1.106,corners(.050,.022,.008,(-.092,-.237))),
           (1.100,corners(.034,.015,.007,(-.092,-.237)))]
    folded(m,stack,[1,15,11,11],lambda x,y,z:(.5+x*3.,y*.72+z))
    for z in (-.058,.096,.245,.352):
        hatch=[(.335,corners(.316,.037,.019,(0,z))),(.358,corners(.334,.044,.023,(.003,z))),
               (.392,corners(.300,.039,.016,(.003,z))),(.409,corners(.281,.035,.018,(.003,z)))]
        folded(m,hatch,[11,1,3],lambda x,y,zz:(.5+x,.55+(zz-z)*5))
    return m

def main():
    studio()
    ordinary=material("Metal e madeira","distritos.png",.70,.10)
    paint=material("Pintura_Patrimonio","distritos.png",.83)
    lens=material("Difusor","distritos.png",.37)
    definitions={
        "terminal": terminal(), "bancada": workbench(), "painel_ferramentas": tool_board(),
        "porta_enrolar": shutter(), "conteiner": container(), "tambor": drum(),
        "caixa_carga": crate(), "pneu_oficina": spare(), "luminaria": luminaire(),
        "poste": pole(), "balizador": bollard(), "rocha_1": escarpment(),
        "rocha_2": escarpment(seed=1), "morro": escarpment(high=True,seed=2),
        "arvore_1": tree(0), "arvore_2": tree(1),
        "assento": seat(), "galpao": warehouse(), "cargueiro": freighter(),
    }
    objects=[]
    for id, mesh in definitions.items():
        obj=mesh.build(id,[paint,ordinary,lens],collection(id))
        objects.append(obj)
        print(f"{id}: {len(obj.data.polygons)} faces")
    export(objects,"assets/models/props/distritos.glb")
    for i,obj in enumerate(objects):
        obj.location=((i%4-1.5)*5.1,(i//4)*5.0,0)
    save("distritos.blend",objects[1])


if __name__=="__main__":
    main()
