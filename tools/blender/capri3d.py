"""Builds Capri as a rigged, low-poly 3D model in Blender and renders her.

Every body part is a faceted prism or blade weighted 100% to one bone, which
matches her angular design and keeps posing and retargeting simple.

    blender -b --factory-startup --python tools/blender/capri3d.py

Writes to art/capri/3d/:
    capri.blend              the model and its armature
    renders/view_<n>.png     front, three-quarter, side and back views (rest pose)
    renders/pose_<name>.png  each pose in POSES, three-quarter view
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "capri" / "3d"

# Her palette (sRGB hex), the same as the 2D layers.
PALETTE = {
    "black": "080606",
    "red": "F92853",
    "green": "6EF067",
    "purple": "A232A0",
    "white": "FFFDF2",
    "blue": "5575FF",
    "navy": "11163A",
    "ring": "57A85A",
}

# Character faces -Y, Z up. Her right side is -X.
BONES = {
    # name: (head, tail, parent)
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "pelvis": ((0, 0, 0.92), (0, 0, 1.02), "root"),
    "spine": ((0, 0, 1.02), (0, 0, 1.18), "pelvis"),
    "chest": ((0, 0, 1.18), (0, 0, 1.38), "spine"),
    "neck": ((0, 0, 1.38), (0, 0, 1.49), "chest"),
    "head": ((0, 0, 1.49), (0, 0, 1.74), "neck"),
}
for side, sx in (("L", 1), ("R", -1)):
    a = math.radians(48)   # A-pose arm angle below horizontal
    shoulder = Vector((0.16 * sx, 0, 1.36))
    elbow = shoulder + Vector((math.cos(a) * sx, 0, -math.sin(a))) * 0.29
    wrist = elbow + Vector((math.cos(a) * sx, 0, -math.sin(a))) * 0.26
    hand = wrist + Vector((math.cos(a) * sx, 0, -math.sin(a))) * 0.15
    BONES.update({
        f"shoulder.{side}": ((0.04 * sx, 0, 1.37), tuple(shoulder), "chest"),
        f"upper_arm.{side}": (tuple(shoulder), tuple(elbow), f"shoulder.{side}"),
        f"forearm.{side}": (tuple(elbow), tuple(wrist), f"upper_arm.{side}"),
        f"hand.{side}": (tuple(wrist), tuple(hand), f"forearm.{side}"),
        f"thigh.{side}": ((0.085 * sx, 0, 0.95), (0.1 * sx, 0, 0.52), "pelvis"),
        f"shin.{side}": ((0.1 * sx, 0, 0.52), (0.11 * sx, 0.01, 0.1), f"thigh.{side}"),
        f"foot.{side}": ((0.11 * sx, 0.01, 0.1), (0.11 * sx, -0.17, 0.0), f"shin.{side}"),
    })


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_materials():
    mats = {}
    for name, hex_ in PALETTE.items():
        rgb = [srgb_to_linear(int(hex_[i:i + 2], 16) / 255) for i in (0, 2, 4)]
        mat = bpy.data.materials.new(f"capri_{name}")
        mat.diffuse_color = (*rgb, 1)
        if mat.node_tree is None:
            mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*rgb, 1)
            bsdf.inputs["Roughness"].default_value = 0.9
        mats[name] = mat
    return mats


class Part:
    """Accumulates faceted geometry for one bone before it becomes an object."""

    def __init__(self, bone):
        self.bone = bone
        self.bm = bmesh.new()
        self.colors = []      # material name per face, in creation order

    def face(self, verts, color):
        self.bm.faces.new(verts)
        self.colors.append(color)

    def verts(self, points):
        return [self.bm.verts.new(p) for p in points]


def basis(axis, hint=Vector((0, 1, 0))):
    axis = axis.normalized()
    if abs(axis.dot(hint)) > 0.95:
        hint = Vector((1, 0, 0))
    side = axis.cross(hint).normalized()
    depth = side.cross(axis).normalized()
    return side, depth


def segment(part, p0, p1, w0, w1, d0=None, d1=None, sides=6, color="black", cap_colors=None):
    """Tapered faceted prism from p0 to p1 with elliptical rings (w = width, d = depth)."""
    p0, p1 = Vector(p0), Vector(p1)
    d0 = w0 if d0 is None else d0
    d1 = w1 if d1 is None else d1
    side, depth = basis(p1 - p0)
    rings = []
    for p, w, d in ((p0, w0, d0), (p1, w1, d1)):
        pts = []
        for i in range(sides):
            a = (i + 0.5) / sides * math.tau
            pts.append(p + side * math.cos(a) * w + depth * math.sin(a) * d)
        rings.append(part.verts(pts))
    for i in range(sides):
        j = (i + 1) % sides
        part.face([rings[0][i], rings[0][j], rings[1][j], rings[1][i]], color)
    caps = cap_colors or (color, color)
    part.face(list(reversed(rings[0])), caps[0])
    part.face(rings[1], caps[1])


def blade(part, base, direction, length, width, thick, roll=0.0, front="red", back="purple"):
    """Flat pointed shard. Faces pointing downward get the `back` colour."""
    base, direction = Vector(base), Vector(direction).normalized()
    side, normal = basis(direction)
    side, normal = (side * math.cos(roll) + normal * math.sin(roll),
                    normal * math.cos(roll) - side * math.sin(roll))
    tip = base + direction * length
    b = part.verts([
        base + side * width / 2 + normal * thick / 2,
        base - side * width / 2 + normal * thick / 2,
        base - side * width / 2 - normal * thick / 2,
        base + side * width / 2 - normal * thick / 2,
    ])
    t = part.verts([tip])[0]
    centre = base + direction * (length / 3)
    for i in range(4):
        tri = [b[i], b[(i + 1) % 4], t]
        n = (tri[1].co - tri[0].co).cross(tri[2].co - tri[0].co)
        if n.dot((tri[0].co + tri[1].co + tri[2].co) / 3 - centre) < 0:
            tri.reverse()
            n = -n
        part.face(tri, back if n.normalized().z < -0.35 else front)
    part.face(list(reversed(b)), front)


def hull(part, points, color):
    verts = part.verts([Vector(p) for p in points])
    result = bmesh.ops.convex_hull(part.bm, input=verts)
    for f in result["geom"]:
        if isinstance(f, bmesh.types.BMFace):
            part.colors.append(color)


def joint(part, centre, radius, color):
    """Faceted knob that hides the gap when a joint bends."""
    c = Vector(centre)
    hull(part, [c + Vector(v) * radius for v in
                ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))], color)


def jagged_blade(part, rng, base, direction, length, width, thick):
    """Hair blade with a smaller blade breaking off its side, for the jagged silhouette.
    Undersides are purple, like the offset shadow on her hair in the anime."""
    roll = rng.uniform(-0.5, 0.5)
    blade(part, base, direction, length, width, thick, roll=roll)
    side, _ = basis(Vector(direction))
    fork = Vector(direction).normalized().lerp(side * rng.choice((-1, 1)), rng.uniform(0.35, 0.6)).normalized()
    blade(part, Vector(base) + Vector(direction).normalized() * length * rng.uniform(0.25, 0.5), fork,
          length * rng.uniform(0.35, 0.55), width * 0.55, thick, roll=roll)


def disc(part, centre, radius, color, sides=20, normal=Vector((0, -1, 0))):
    side, up = basis(normal)
    ring = part.verts([Vector(centre) + (side * math.cos(a) + up * math.sin(a)) * radius
                       for a in (i / sides * math.tau for i in range(sides))])
    part.face(ring if normal.y < 0 else list(reversed(ring)), color)


def build_parts():
    parts = {}

    def P(bone):
        return parts.setdefault(bone, Part(bone))

    # Torso: tiny waist, wide angular hips and chest
    segment(P("pelvis"), (0, 0, 0.86), (0, 0, 1.02), 0.17, 0.085, 0.1, 0.065, sides=6)
    segment(P("spine"), (0, 0, 1.02), (0, 0.005, 1.18), 0.08, 0.1, 0.06, 0.072, sides=6)
    segment(P("chest"), (0, 0.005, 1.18), (0, 0, 1.38), 0.11, 0.14, 0.078, 0.066, sides=6)
    joint(P("chest"), (0, 0, 1.18), 0.085, "black")
    # Red chevron on her chest (left side)
    chest = P("chest")
    v = chest.verts([(0.02, -0.078, 1.33), (0.075, -0.07, 1.33), (0.05, -0.078, 1.22), (0.035, -0.078, 1.27)])
    chest.face([v[0], v[3], v[2], v[1]], "red")

    segment(P("neck"), (0, 0, 1.37), (0, 0.005, 1.5), 0.026, 0.024, sides=5)

    # Head: angular wedge with a pointed chin
    head = P("head")
    hull(head, [
        (0, -0.055, 1.47), (0.045, -0.03, 1.5), (-0.045, -0.03, 1.5),
        (0.085, -0.06, 1.58), (-0.085, -0.06, 1.58), (0.095, -0.05, 1.66), (-0.095, -0.05, 1.66),
        (0.06, 0.06, 1.7), (-0.06, 0.06, 1.7), (0, 0.09, 1.6), (0, -0.07, 1.68), (0, 0.02, 1.75),
        (0.05, 0.05, 1.52), (-0.05, 0.05, 1.52),
    ], "black")

    # Face plate: slanted green panel with the eyes on it
    plate = head.verts([(-0.098, -0.082, 1.575), (0.098, -0.082, 1.595), (0.094, -0.078, 1.675), (-0.09, -0.078, 1.655)])
    plate_back = head.verts([(p.co.x, p.co.y + 0.012, p.co.z) for p in plate])
    head.face(list(reversed(plate)), "green")
    for i in range(4):
        j = (i + 1) % 4
        head.face([plate[i], plate[j], plate_back[j], plate_back[i]], "green")
    for x, z, r in ((-0.042, 1.622, 0.026), (0.045, 1.632, 0.028)):
        y = -0.083
        for color, rr in (("black", 1.0), ("ring", 0.86), ("black", 0.76), ("navy", 0.7), ("blue", 0.62), ("white", 0.33)):
            disc(head, (x, y, z), r * rr, color)
            y -= 0.0008

    # Zigzag mouth on the black lower face
    zig = [(-0.03, 1.535), (-0.015, 1.528), (0, 1.536), (0.015, 1.528), (0.032, 1.536)]
    for (x0, z0), (x1, z1) in zip(zig, zig[1:]):
        q = head.verts([(x0, -0.069, z0 + 0.003), (x1, -0.069, z1 + 0.003), (x1, -0.069, z1 - 0.003), (x0, -0.069, z0 - 0.003)])
        head.face(q, "white")

    # Black horn spikes off the head
    for base, d, ln in (((0.07, 0.0, 1.69), (0.6, 0.1, 1), 0.14), ((-0.07, 0.0, 1.69), (-0.7, 0.2, 1), 0.17),
                        ((0.09, 0.02, 1.62), (1, 0.3, 0.2), 0.16), ((-0.09, 0.02, 1.62), (-1, 0.4, 0.4), 0.13)):
        blade(head, base, d, ln, 0.05, 0.02, front="black", back="black")

    # Hair: a big mass of broad jagged blades swept up, out and back
    rng = random.Random(11)
    centre = Vector((0, 0.04, 1.64))
    for _ in range(26):
        d = Vector((rng.gauss(0, 1.1), abs(rng.gauss(0, 0.6)) + 0.2, abs(rng.gauss(0.55, 0.5)) + 0.05)).normalized()
        length = rng.uniform(0.28, 0.5) + max(0, d.z) * 0.12 + abs(d.x) * 0.15
        jagged_blade(head, rng, centre + d * 0.07, d, length, rng.uniform(0.16, 0.3), rng.uniform(0.03, 0.05))
    for _ in range(8):    # long strands down her back
        d = Vector((rng.uniform(-0.7, 0.7), rng.uniform(0.5, 0.9), rng.uniform(-1.1, -0.4))).normalized()
        jagged_blade(head, rng, centre + Vector((0, 0.05, -0.02)), d, rng.uniform(0.4, 0.6), rng.uniform(0.15, 0.24), 0.035)

    # Limbs. Her right (-X): green upper arm and hand, black leg with a green thigh.
    # Her left (+X): black arm with a red cuff, red leg.
    for side, sx in (("L", 1), ("R", -1)):
        b = {k: (Vector(v[0]), Vector(v[1])) for k, v in BONES.items()}
        right = side == "R"
        arm = "green" if right else "black"
        s, e = b[f"shoulder.{side}"]
        segment(P(f"shoulder.{side}"), s, e, 0.04, 0.05, sides=5, color=arm)
        s, e = b[f"upper_arm.{side}"]
        joint(P(f"upper_arm.{side}"), s, 0.05, arm)
        segment(P(f"upper_arm.{side}"), s, e, 0.05, 0.03, sides=5, color=arm)
        s, e = b[f"forearm.{side}"]
        joint(P(f"forearm.{side}"), s, 0.03, "black")
        mid = s.lerp(e, 0.78)
        segment(P(f"forearm.{side}"), s, mid, 0.03, 0.022, sides=5)
        segment(P(f"forearm.{side}"), mid, e, 0.024, 0.022, sides=5, color="black" if right else "red")
        s, e = b[f"hand.{side}"]
        hand = P(f"hand.{side}")
        joint(hand, s, 0.024, arm)
        palm_end = s.lerp(e, 0.45)
        segment(hand, s, palm_end, 0.032, 0.045, 0.013, 0.013, sides=4, color=arm)
        axis = (e - s).normalized()
        side_v, _ = basis(axis)
        for k in (-1, 0, 1):   # long pointed fingers
            fdir = (axis + side_v * k * 0.25).normalized()
            blade(hand, palm_end + side_v * k * 0.024, fdir, 0.11 + 0.02 * (k == 0), 0.018, 0.011, front=arm, back=arm)

        leg = "black" if right else "red"
        s, e = b[f"thigh.{side}"]
        joint(P(f"thigh.{side}"), s, 0.085, "green" if right else leg)
        if right:
            band = s.lerp(e, 0.4)
            segment(P(f"thigh.{side}"), s, band, 0.095, 0.08, 0.09, 0.075, color="green")
            segment(P(f"thigh.{side}"), band, e, 0.08, 0.05, 0.075, 0.05)
        else:
            segment(P(f"thigh.{side}"), s, e, 0.095, 0.05, 0.09, 0.05, color=leg)
        s, e = b[f"shin.{side}"]
        joint(P(f"shin.{side}"), s, 0.05, leg)
        segment(P(f"shin.{side}"), s, e, 0.052, 0.022, 0.05, 0.024, color=leg)
        s, e = b[f"foot.{side}"]
        foot = P(f"foot.{side}")
        joint(foot, s, 0.026, leg)
        blade(foot, s + Vector((0, 0.01, 0)), (e - s), (e - s).length + 0.08, 0.07, 0.045, front=leg, back=leg)
        blade(foot, s + Vector((0, 0.02, 0.0)), (0, 0.35, -1), 0.13, 0.035, 0.022, front=leg, back=leg)   # heel spike

    # Her head is large in the anime: scale it (with hair and horns) from the neck.
    pivot = Vector((0, 0, 1.49))
    for v in parts["head"].bm.verts:
        v.co = pivot + (v.co - pivot) * 1.3

    # Floating shards around her
    shards = P("chest")
    for base, d, ln, w, front in (((0.5, 0.15, 1.62), (1, -0.2, 0.6), 0.2, 0.08, "red"),
                                  ((-0.55, 0.1, 1.4), (-0.4, 0, 1), 0.24, 0.09, "red"),
                                  ((0.42, 0.0, 1.25), (0.3, -0.3, 1), 0.16, 0.06, "red"),
                                  ((-0.38, -0.05, 0.95), (-0.2, 0, -1), 0.22, 0.07, "green"),
                                  ((0.36, -0.1, 1.05), (1, 0, 0.8), 0.12, 0.05, "red")):
        blade(shards, base, d, ln, w, 0.02, front=front, back="purple")

    return parts


def build_armature():
    data = bpy.data.armatures.new("CapriRig")
    rig = bpy.data.objects.new("CapriRig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, _) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
    for name, (_, _, parent) in BONES.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    return rig


def build_mesh(rig, mats):
    names = list(PALETTE)
    objects = []
    for bone, part in build_parts().items():
        mesh = bpy.data.meshes.new(f"part_{bone}")
        part.bm.to_mesh(mesh)
        part.bm.free()
        for name in names:
            mesh.materials.append(mats[name])
        for poly, color in zip(mesh.polygons, part.colors):
            poly.material_index = names.index(color)
        obj = bpy.data.objects.new(f"part_{bone}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.vertex_groups.new(name=bone).add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        objects.append(obj)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = body.data.name = "Capri"
    body.parent = rig
    body.modifiers.new("Armature", "ARMATURE").object = rig
    return body


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    shading = scene.display.shading
    shading.light = "FLAT"
    shading.color_type = "MATERIAL"
    shading.show_object_outline = True
    shading.object_outline_color = (0.0, 0.0, 0.0)
    scene.display.render_aa = "8"
    world = bpy.data.worlds.new("Stage")
    world.color = (0.05, 0.006, 0.025)
    scene.world = world
    scene.render.resolution_x, scene.render.resolution_y = 640, 900

    target = bpy.data.objects.new("CamTarget", None)
    target.location = (0, 0, 1.05)
    scene.collection.objects.link(target)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    track = cam.constraints.new("TRACK_TO")
    track.target = target
    track.track_axis, track.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"
    scene.camera = cam
    return cam


def render(cam, angle, path):
    a = math.radians(angle)
    cam.location = (math.sin(a) * 3.9, -math.cos(a) * 3.9, 1.2)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


# Poses: root drop (m), then (bone, world direction) pairs applied parent-first.
# Directions use her facing: -Y is forward, -X is her right.
ARMS_DOWN = [("upper_arm.L", (0.3, 0.05, -1)), ("forearm.L", (0.15, -0.15, -1)), ("hand.L", (0.1, -0.1, -1)),
             ("upper_arm.R", (-0.3, 0.05, -1)), ("forearm.R", (-0.15, -0.15, -1)), ("hand.R", (-0.1, -0.1, -1))]
POSES = {
    "stand": (0.0, [("head", (0.1, -0.1, 1))] + ARMS_DOWN),
    "crouch": (0.24, [
        ("spine", (0, -0.35, 1)), ("chest", (0.12, -0.15, 1)), ("head", (0.25, -0.1, 1)),
        ("thigh.R", (-0.85, -0.15, -0.55)), ("shin.R", (-0.55, 0.05, -1)), ("foot.R", (-0.3, -1, -0.15)),
        ("thigh.L", (0.3, -0.75, -0.55)), ("shin.L", (0.1, 0.25, -1)), ("foot.L", (0.25, -1, 0)),
        ("upper_arm.R", (-0.15, -0.45, -1)), ("forearm.R", (0.2, -0.5, -1)), ("hand.R", (0.15, -0.3, -1)),
        ("upper_arm.L", (0.55, 0.1, -0.8)), ("forearm.L", (0.25, -0.7, -0.3)), ("hand.L", (0.1, -1, 0.1)),
    ]),
    "sit": (0.44, [
        ("spine", (0, 0.12, 1)), ("head", (-0.1, -0.15, 1)),
        ("thigh.L", (0.12, -1, 0.04)), ("shin.L", (0.02, -0.12, -1)), ("foot.L", (0.05, -1, -0.35)),
        ("thigh.R", (-0.12, -1, 0.04)), ("shin.R", (-0.02, -0.12, -1)), ("foot.R", (-0.05, -1, -0.35)),
        ("upper_arm.L", (0.3, -0.2, -1)), ("forearm.L", (0.05, -1, -0.35)), ("hand.L", (0, -1, -0.3)),
        ("upper_arm.R", (-0.3, -0.2, -1)), ("forearm.R", (-0.05, -1, -0.35)), ("hand.R", (0, -1, -0.3)),
    ]),
    "hack": (0.0, ARMS_DOWN + [
        ("chest", (-0.1, -0.05, 1)), ("head", (-0.12, -0.2, 1)),
        ("upper_arm.R", (-0.35, -1, 0.15)), ("forearm.R", (-0.2, -1, 0.2)), ("hand.R", (-0.1, -1, 0.3)),
    ]),
}


def apply_pose(rig, pose):
    drop, aims = pose
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    rig.pose.bones["root"].location = (0, 0, -drop)   # root's local Y is world Z
    bpy.context.view_layer.update()
    for name, direction in aims:
        pb = rig.pose.bones[name]
        current = (pb.tail - pb.head).normalized()
        turn = current.rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
        head = pb.head.copy()
        pb.matrix = Matrix.Translation(head) @ turn @ Matrix.Translation(-head) @ pb.matrix
        bpy.context.view_layer.update()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    rig = build_armature()
    build_mesh(rig, mats)
    cam = setup_render()
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "capri.blend"))

    renders = OUT / "renders"
    renders.mkdir(parents=True, exist_ok=True)
    for i, angle in enumerate((0, 40, 90, 180)):
        render(cam, angle, renders / f"view_{i}.png")
    for name, pose in POSES.items():
        apply_pose(rig, pose)
        render(cam, 35, renders / f"pose_{name}.png")
    apply_pose(rig, (0.0, []))


main()
