"""Blender authoring utilities. All input coordinates use the game's Y-up convention."""
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "art/textures"
CELL = 128
GRID = 4


def vector(point):
    x, y, z = point
    return Vector((x, -z, y))


def mix(a, b, factor):
    return a + (b - a) * factor


def blend(a, b, factor):
    return tuple(mix(left, right, factor) for left, right in zip(a, b))


def sample(stations, t):
    for (a, av), (b, bv) in zip(stations, stations[1:]):
        if t <= b:
            return mix(av, bv, (t - a) / (b - a))
    return stations[-1][1]


def tile(index, u, v, columns=GRID, rows=GRID):
    inset = 3 / CELL
    u = mix(inset, 1 - inset, max(0, min(1, u)))
    v = mix(inset, 1 - inset, max(0, min(1, v)))
    return ((index % columns + u) / columns, 1 - (index // columns + 1 - v) / rows)


def atlas_uv(index, coordinates, columns=GRID, rows=GRID):
    return [tile(index, u, v, columns, rows) for u, v in coordinates]


def material(name, texture, roughness=0.6, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    image = bpy.data.images.load(str(TEXTURES / texture), check_existing=True)
    if not image.packed_file:
        image.pack()
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    mat.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color"])
    return mat


class Mesh:
    def __init__(self):
        self.points = []
        self.polys = []
        self.weld = {}

    def point(self, point):
        key = tuple(round(value, 6) for value in point)
        if key not in self.weld:
            self.weld[key] = len(self.points)
            self.points.append(point)
        return self.weld[key]

    def face(self, points, slot=0, uv=None, smooth=True):
        vertices = [self.point(point) for point in points]
        keep = [i for i, idx in enumerate(vertices) if idx not in vertices[:i]]
        if len(keep) < 3:
            return
        if uv is None:
            uv = [(0.5, 0.5)] * len(vertices)
        self.polys.append(([vertices[i] for i in keep], slot, [uv[i] for i in keep], smooth))

    def strip(self, first, last, slot=0, uv=None, smooth=True, closed=True):
        for i in range(len(first) if closed else len(first) - 1):
            k = (i + 1) % len(first)
            points = [first[i], first[k], last[k], last[i]]
            self.face(points, slot, uv(i, k, points) if uv else None, smooth)

    def build(self, name, materials, collection):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([vector(point) for point in self.points], [], [p[0] for p in self.polys])
        mesh.validate(clean_customdata=False)
        for mat in materials:
            mesh.materials.append(mat)
        layer = mesh.uv_layers.new(name="UVMap")
        for poly, (_, slot, uv, smooth) in zip(mesh.polygons, self.polys):
            poly.material_index = slot
            poly.use_smooth = smooth
            for idx, coord in zip(poly.loop_indices, uv):
                layer.data[idx].uv = coord
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for edge in bm.edges:
            edge.smooth = not edge.is_manifold or edge.calc_face_angle(0) < 0.94
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        return obj


def collection(name):
    group = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(group)
    return group


def export(objects, path):
    if isinstance(path, str):
        path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[-1]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_tangents=False)


def studio():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def save(name, focus=None):
    if focus is not None:
        bpy.ops.object.select_all(action="DESELECT")
        focus.select_set(True)
        bpy.context.view_layer.objects.active = focus
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_distance = 9
                area.spaces.active.region_3d.view_location = (0, 0, 0.6)
                area.spaces.active.shading.color_type = "MATERIAL"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art" / name), compress=True)
