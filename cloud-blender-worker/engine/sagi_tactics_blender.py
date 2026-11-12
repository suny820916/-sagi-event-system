import bpy
import json
import math
import os
import sys
from mathutils import Vector


def args_after_dd():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1:]


def hex_rgba(h, alpha=1.0):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)) + (alpha,)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name, color, rough=.55, metallic=0.0, emission_strength=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_strength:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def cube(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    return o


def sphere(name, loc, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12,
        ring_count=6,
        radius=radius,
        location=loc,
    )
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    return o


def cyl(name, loc, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10,
        radius=radius,
        depth=depth,
        location=loc,
    )
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    return o


def torus(name, loc, major, minor, mat):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=40,
        minor_segments=8,
        location=loc,
    )
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    return o


def line(name, p1, p2, width, mat, z=.205):
    c = bpy.data.curves.new(name, "CURVE")
    c.dimensions = "3D"
    c.bevel_depth = width
    c.bevel_resolution = 1
    s = c.splines.new("POLY")
    s.points.add(1)
    s.points[0].co = (p1[0], p1[1], z, 1)
    s.points[1].co = (p2[0], p2[1], z, 1)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def polyline(name, pts, width, mat, closed=True, z=.205):
    c = bpy.data.curves.new(name, "CURVE")
    c.dimensions = "3D"
    c.bevel_depth = width
    c.bevel_resolution = 1
    s = c.splines.new("POLY")
    s.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        s.points[i].co = (p[0], p[1], z, 1)
    s.use_cyclic_u = closed
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def key(obj, path, frame):
    obj.keyframe_insert(data_path=path, frame=frame)


def smooth_action(obj):
    # Blender 5.x uses layered/slotted Actions and no longer exposes
    # Action.fcurves through the legacy API. Default keyframe interpolation
    # is already Bezier, so V1 deliberately leaves curve data untouched.
    # We will add SAGI camera-specific easing with the Blender 5.x API later.
    return


args = args_after_dd()
if len(args) < 2:
    raise SystemExit(
        "Usage: blender --background --python sagi_tactics_blender.py -- config.json output_dir"
    )

cfg_path = os.path.abspath(args[0])
out_dir = os.path.abspath(args[1])
os.makedirs(out_dir, exist_ok=True)
with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

fps = int(cfg.get("fps", 24))
dur = float(cfg.get("duration_sec", 12))
w, h = cfg.get("resolution", [540, 960])
pal = cfg["palette"]

clear_scene()

scene = bpy.context.scene
scene.render.resolution_x = int(w)
scene.render.resolution_y = int(h)
scene.render.resolution_percentage = 100
scene.render.fps = fps
scene.frame_start = 1
scene.frame_end = max(1, int(round(dur * fps)))
requested_engine = cfg.get("render_engine", "BLENDER_EEVEE")
if requested_engine == "BLENDER_EEVEE_NEXT":
    requested_engine = "BLENDER_EEVEE"

engine_ok = False
for candidate in (requested_engine, "BLENDER_EEVEE", "BLENDER_WORKBENCH", "CYCLES"):
    try:
        scene.render.engine = candidate
        engine_ok = True
        break
    except (TypeError, ValueError):
        continue

if not engine_ok:
    raise RuntimeError("No supported Blender render engine is available")

frames_dir = os.path.join(out_dir, "frames")
os.makedirs(frames_dir, exist_ok=True)
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.filepath = os.path.join(frames_dir, "frame_")
scene.world.color = hex_rgba(pal["background"])[:3]

# Workbench is the fast cloud preview renderer. Keep material colors
# and shadows readable so geometry/camera can be reviewed before final Eevee.
try:
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "WORLD"
except Exception:
    pass

try:
    scene.render.image_settings.color_mode = "RGB"
except Exception:
    pass
try:
    scene.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass

m_pitch = material("PITCH", hex_rgba(pal["pitch"]), rough=.78)
m_pitch_alt = material(
    "PITCH_ALT",
    hex_rgba(pal.get("pitch_alt", "#131719")),
    rough=.80,
)
m_line = material("LINE", hex_rgba(pal["pitch_line"]), rough=.52)
m_y = material(
    "OWN_PRIMARY",
    hex_rgba(pal["own_primary"]),
    rough=.42,
    emission_strength=.10,
)
m_y2 = material(
    "OWN_SECONDARY",
    hex_rgba(pal["own_secondary"]),
    rough=.48,
)
m_g = material(
    "OPPONENT",
    hex_rgba(pal["opponent"]),
    rough=.58,
)
m_ring = material(
    "RING",
    hex_rgba(pal.get("ring", pal["own_primary"])),
    rough=.30,
    emission_strength=2.0,
)
m_ball = material(
    "BALL",
    (0.94, .94, .94, 1),
    rough=.33,
)

# Floating pitch
cube("PITCH", (0, 0, 0), (34, 52.5, .18), m_pitch)

# Teactics-like low-contrast horizontal spatial bands.
# They support depth reading without turning the pitch into a grass texture.
band_h = 105.0 / 8.0
for i in range(8):
    if i % 2 == 0:
        y0 = -52.5 + band_h * (i + .5)
        cube(
            f"PITCH_BAND_{i}",
            (0, y0, .185),
            (33.95, band_h / 2.0, .004),
            m_pitch_alt,
        )

lw = .055
polyline(
    "TOUCHLINE",
    [(-34,-52.5),(34,-52.5),(34,52.5),(-34,52.5)],
    lw,
    m_line,
)
line("HALFWAY", (-34,0), (34,0), lw, m_line)

bpy.ops.curve.primitive_bezier_circle_add(
    radius=9.15,
    location=(0,0,.205),
)
cc = bpy.context.object
cc.data.bevel_depth = lw
cc.data.bevel_resolution = 1
cc.data.materials.append(m_line)

for sy in (-1, 1):
    y = sy * 52.5
    y2 = sy * (52.5 - 16.5)
    polyline(
        "BOX",
        [(-20.15,y),(20.15,y),(20.15,y2),(-20.15,y2)],
        lw,
        m_line,
    )


def create_player(name, data):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = (
        data["pos"][0],
        data["pos"][1],
        .205,
    )
    root.rotation_euler[2] = math.radians(
        float(data.get("yaw", 0))
    )
    # Slightly larger tactical marker: still miniature, but readable on mobile.
    root.scale = (1.16, 1.16, 1.16)

    matp = (
        m_g
        if data["team"] == "opp"
        else (
            m_y
            if data.get("role") == "primary"
            else m_y2
        )
    )

    # Minimal figure: stable silhouette, small head,
    # solid torso, short/thin limbs, almost no gait.
    torso = cube(
        name + "_TORSO",
        (0,0,1.03),
        (.225,.145,.36),
        matp,
    )
    head = sphere(
        name + "_HEAD",
        (0,0,1.58),
        .16,
        matp,
    )
    la = cyl(
        name + "_LA",
        (-.285,0,1.05),
        .050,
        .50,
        matp,
    )
    ra = cyl(
        name + "_RA",
        (.285,0,1.05),
        .050,
        .50,
        matp,
    )
    ll = cyl(
        name + "_LL",
        (-.105,0,.42),
        .060,
        .70,
        matp,
    )
    rl = cyl(
        name + "_RL",
        (.105,0,.42),
        .060,
        .70,
        matp,
    )

    for ch in (torso, head, la, ra, ll, rl):
        ch.parent = root

    ring = torus(
        name + "_RING",
        (0,0,.04),
        .66,
        .024,
        m_ring,
    )
    ring.parent = root
    ring.hide_render = data.get("role") != "primary"

    return root, ring


players = {}
rings = {}
for name, data in cfg["players"].items():
    players[name], rings[name] = create_player(
        name,
        data,
    )

ball = sphere(
    "BALL",
    (
        players["GK"].location.x,
        players["GK"].location.y,
        .37,
    ),
    .16,
    m_ball,
)

# Light rig
bpy.ops.object.light_add(
    type="AREA",
    location=(0,-8,28),
)
key_light = bpy.context.object
key_light.data.energy = 850
key_light.data.shape = "DISK"
key_light.data.size = 24
look_at(key_light, (0,0,0))

bpy.ops.object.light_add(
    type="AREA",
    location=(24,-16,14),
)
rim = bpy.context.object
rim.data.energy = 420
rim.data.size = 14
look_at(rim, (0,0,0))

# Camera presets are stable inside each tactical idea.
bpy.ops.object.camera_add()
cam = bpy.context.object
scene.camera = cam

camera_presets = {
    "shape": {
        "loc": (0,-69,69),
        "target": (0,-2,0),
        "lens": 56,
    },
    "relation": {
        "loc": (18,-56,34),
        "target": (3,-14,1.0),
        "lens": 62,
    },
    "result": {
        "loc": (-12,-55,41),
        "target": (0,-5,1.0),
        "lens": 60,
    },
}

camera_last = None
camera_last_t = 0.0


def apply_camera_pose(p, frame):
    cam.location = p["loc"]
    cam.data.lens = p["lens"]
    look_at(cam, p["target"])
    key(cam, "location", frame)
    key(cam, "rotation_euler", frame)
    cam.data.keyframe_insert("lens", frame=frame)


def camera_key(preset, t):
    # Teactics grammar: stable composition inside an idea.
    # Reframe quickly only just before the next tactical question.
    global camera_last, camera_last_t
    p = camera_presets[preset]
    fr = 1 + round(t * fps)

    if camera_last is None or t <= 0.001:
        apply_camera_pose(p, fr)
        camera_last = p
        camera_last_t = t
        return

    transition = 0.58
    start_t = max(camera_last_t, t - transition)
    start_fr = 1 + round(start_t * fps)

    # Duplicate the previous pose at transition start = camera stays locked
    # through the concept, then makes one short purposeful move.
    apply_camera_pose(camera_last, start_fr)
    apply_camera_pose(p, fr)

    camera_last = p
    camera_last_t = t


def focus_player(name, t):
    fr = 1 + round(t * fps)
    for n, r in rings.items():
        r.hide_render = n != name
        r.keyframe_insert(
            "hide_render",
            frame=fr,
        )


def move_player(name, target, t0, dur):
    o = players[name]
    f0 = 1 + round(t0 * fps)
    f1 = 1 + round((t0 + dur) * fps)

    key(o, "location", f0)
    o.location.x = float(target[0])
    o.location.y = float(target[1])
    key(o, "location", f1)

    smooth_action(o)


def pass_ball(a, b, release, arrive):
    aa = players[a]
    bb = players[b]
    f0 = 1 + round(release * fps)
    f1 = 1 + round(arrive * fps)

    ball.location = (
        aa.location.x,
        aa.location.y,
        .37,
    )
    key(ball, "location", f0)

    ball.location = (
        bb.location.x,
        bb.location.y,
        .37,
    )
    key(ball, "location", f1)

    smooth_action(ball)


def add_space(ev):
    sp = torus(
        "SPACE",
        (
            ev["center"][0],
            ev["center"][1],
            .24,
        ),
        1.0,
        .035,
        m_ring,
    )
    sp.scale = (
        float(ev["radius"][0]),
        float(ev["radius"][1]),
        1,
    )

    f0 = 1 + round(float(ev["t"]) * fps)
    f1 = 1 + round(
        (
            float(ev["t"])
            + float(ev["duration"])
        )
        * fps
    )

    sp.hide_render = True
    sp.keyframe_insert(
        "hide_render",
        frame=max(1, f0 - 1),
    )

    sp.hide_render = False
    sp.keyframe_insert(
        "hide_render",
        frame=f0,
    )

    sp.hide_render = True
    sp.keyframe_insert(
        "hide_render",
        frame=f1,
    )


camera_key("shape", 0)

for ev in cfg.get("events", []):
    typ = ev.get("type")

    if typ == "camera":
        camera_key(
            ev["preset"],
            float(ev["t"]),
        )

    elif typ == "focus":
        focus_player(
            ev["player"],
            float(ev["t"]),
        )

    elif typ in ("player_move", "defender_shift"):
        move_player(
            ev["player"],
            ev["to"],
            float(ev["t"]),
            float(ev["duration"]),
        )

    elif typ == "pass":
        pass_ball(
            ev["from"],
            ev["to"],
            float(ev["release"]),
            float(ev["arrive"]),
        )

    elif typ == "space":
        add_space(ev)

smooth_action(cam)

blend_path = os.path.join(
    out_dir,
    "scene.blend",
)

bpy.ops.wm.save_as_mainfile(
    filepath=blend_path,
)

bpy.ops.render.render(
    animation=True,
)

print(
    "SAGI_RENDER_DONE",
    scene.render.filepath,
    blend_path,
)
