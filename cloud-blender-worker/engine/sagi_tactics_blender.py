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

    # Six-yard box: important spatial reference once the camera moves
    # into the finishing phase.
    y6 = sy * (52.5 - 5.5)
    polyline(
        "SIX_YARD",
        [(-9.16,y),(9.16,y),(9.16,y6),(-9.16,y6)],
        lw,
        m_line,
    )

    # Minimal goal frame. Keep it geometric and readable from a high
    # tactical camera; no net texture or broadcast-style detail.
    goal_y = sy * 52.72
    back_y = sy * 54.65
    post_z = 1.22
    cube(
        "GOAL_POST_L",
        (-3.66, goal_y, post_z),
        (.055, .055, 1.22),
        m_line,
    )
    cube(
        "GOAL_POST_R",
        (3.66, goal_y, post_z),
        (.055, .055, 1.22),
        m_line,
    )
    cube(
        "GOAL_BAR",
        (0, goal_y, 2.44),
        (3.72, .055, .055),
        m_line,
    )
    # Ground-depth rails make the goal mouth legible from above.
    line(
        "GOAL_SIDE_L",
        (-3.66, goal_y),
        (-3.66, back_y),
        .045,
        m_line,
        z=.23,
    )
    line(
        "GOAL_SIDE_R",
        (3.66, goal_y),
        (3.66, back_y),
        .045,
        m_line,
        z=.23,
    )
    line(
        "GOAL_BACK",
        (-3.66, back_y),
        (3.66, back_y),
        .045,
        m_line,
        z=.23,
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
    # Teactics-style miniature figure: readable, but never dominant.
    # V03 reduces the overall scale and gives the limbs a quiet natural stance
    # so players read as people rather than rigid chess pieces.
    root.scale = (1.10, 1.10, 1.10)

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
    # V06 MOTION ENGINE: limbs rotate around actual shoulder / hip pivots.
    # Earlier versions rotated each cylinder around its own centre, which
    # created the stiff "chess-piece" motion visible in the preview.
    def make_limb(suffix, joint_loc, radius, length, rest_y=0.0):
        pivot = bpy.data.objects.new(name + suffix, None)
        bpy.context.collection.objects.link(pivot)
        pivot.parent = root
        pivot.location = joint_loc
        pivot.rotation_euler[1] = math.radians(rest_y)

        mesh = cyl(
            name + suffix + "_MESH",
            (0,0,0),
            radius,
            length,
            matp,
        )
        mesh.parent = pivot
        # Cylinder extends down from the joint rather than spinning around
        # its midpoint. This single change makes starts/stops read as running.
        mesh.location = (0,0,-length * .5)
        return pivot, mesh

    la, la_mesh = make_limb("_LA", (-.285,0,1.30), .048, .50, -10)
    ra, ra_mesh = make_limb("_RA", (.285,0,1.30), .048, .50, 10)
    ll, ll_mesh = make_limb("_LL", (-.105,0,.78), .058, .72, 3)
    rl, rl_mesh = make_limb("_RL", (.105,0,.78), .058, .72, -3)

    for ch in (torso, head):
        ch.parent = root

    ring = torus(
        name + "_RING",
        (0,0,.04),
        .66,
        .024,
        m_ring,
    )
    ring.parent = root
    # Focus rings are editorial annotations, not permanent player badges.
    # Start hidden and reveal only through explicit focus events.
    ring.hide_render = True

    return root, ring


players = {}
rings = {}
for name, data in cfg["players"].items():
    players[name], rings[name] = create_player(
        name,
        data,
    )

ball_owner = cfg.get("ball_start_player", "GK")
if ball_owner not in players:
    raise ValueError(f"Unknown ball_start_player: {ball_owner}")

ball = sphere(
    "BALL",
    (
        players[ball_owner].location.x,
        players[ball_owner].location.y,
        .37,
    ),
    .20,
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
    # V05: elevated tactical angles keep the playing surface in frame.
    "shape": {"loc": (0,-17,125), "target": (0,-10,0), "lens": 57},
    "relation": {"loc": (6,-16,94), "target": (3,-12,0), "lens": 57},
    "result": {"loc": (3,10,96), "target": (3,12,0), "lens": 55},
    "finish": {"loc": (4,28,83), "target": (4,36,0), "lens": 53},
    # Christmas-tree lesson cameras: same elevated Teactics-style axis,
    # with target depth changing by tactical idea.
    "midfield": {"loc": (18,-32,62), "target": (0,-7,0), "lens": 60},
    "between_lines": {"loc": (10,-18,58), "target": (0,9,0), "lens": 58},
    # Oblique width view: fitting a 68m pitch into a portrait frame by
    # rotating the spatial axis, instead of simply pulling the camera higher.
    "width": {"loc": (28,-30,76), "target": (0,5,0), "lens": 56},
    "right_flank": {"loc": (29,-6,60), "target": (20,16,0), "lens": 60},
    # Final-third cameras are intentionally tighter: the teaching subject
    # should occupy the portrait frame instead of floating in empty pitch.
    "final_third": {"loc": (14,3,54), "target": (7,28,0), "lens": 64},
    "box_relation": {"loc": (12,13,50), "target": (5,34,0), "lens": 66},
    "finish_close": {"loc": (7,23,46), "target": (0,41,0), "lens": 68},
    "def_compact": {"loc": (18,-38,72), "target": (0,-8,0), "lens": 60},
    # Defensive teaching shots keep the full relationship inside frame.
    "def_force_wide": {"loc": (20,-32,74), "target": (20,-8,0), "lens": 59},
    "def_triangle": {"loc": (20,-26,72), "target": (17,-12,0), "lens": 58},
    # Move to the weak-side half-space rather than looking across the
    # touchline from the opposite side; this removes the black pitch void.
    "def_weakness": {"loc": (3,-30,90), "target": (-17,-14,0), "lens": 58},
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
    # Hard editorial reframe: reserve this for chapter changes.
    global camera_last, camera_last_t
    p = camera_presets[preset]
    fr = 1 + round(t * fps)

    if camera_last is None or t <= 0.001:
        apply_camera_pose(p, fr)
        camera_last = p
        camera_last_t = t
        return

    transition = 0.38
    start_t = max(camera_last_t, t - transition)
    start_fr = 1 + round(start_t * fps)
    apply_camera_pose(camera_last, start_fr)
    apply_camera_pose(p, fr)
    camera_last = p
    camera_last_t = t


def mix_pose(a, b, u):
    def mix3(x, y):
        return tuple(float(x[i]) + (float(y[i]) - float(x[i])) * u for i in range(3))
    return {
        "loc": mix3(a["loc"], b["loc"]),
        "target": mix3(a["target"], b["target"]),
        "lens": float(a["lens"]) + (float(b["lens"]) - float(a["lens"])) * u,
    }


def camera_glide(preset, t, duration):
    """Continuous tactical glide with moving position, target and lens."""
    global camera_last, camera_last_t
    target = camera_presets[preset]

    if camera_last is None:
        apply_camera_pose(target, 1 + round(float(t) * fps))
        camera_last = target
        camera_last_t = float(t)
        return

    start_pose = camera_last
    f0 = 1 + round(float(t) * fps)
    f1 = 1 + round((float(t) + float(duration)) * fps)
    span = max(1, f1 - f0)

    # Multiple look-at keys prevent the view from feeling like a preset cut.
    for u in (0.0, 0.28, 0.62, 1.0):
        eased = u * u * (3.0 - 2.0 * u)
        fr = round(f0 + span * u)
        apply_camera_pose(mix_pose(start_pose, target, eased), fr)

    camera_last = target
    camera_last_t = float(t) + float(duration)



def tactical_space_pose(center, base_preset="between_lines", height=None, lens=None):
    """Build a camera pose around the NEXT advantageous space, not the ball.

    The base preset preserves the established pitch angle; only the tactical
    look-at point is translated toward the future zone. This keeps a stable
    visual language while allowing the camera to arrive before the action.
    """
    base = camera_presets[base_preset]
    cx, cy = float(center[0]), float(center[1])
    tx, ty, tz = base["target"]
    dx = cx - float(tx)
    dy = cy - float(ty)

    # Move only part of the camera translation. The target leads more than
    # the camera itself, creating a purposeful "look ahead" composition.
    loc = (
        float(base["loc"][0]) + dx * .42,
        float(base["loc"][1]) + dy * .42,
        float(height) if height is not None else float(base["loc"][2]),
    )
    return {
        "loc": loc,
        "target": (cx, cy, 0.0),
        "lens": float(lens) if lens is not None else float(base["lens"]),
    }


def camera_lead_space(center, t, duration, base_preset="between_lines", height=None, lens=None):
    """Glide into an empty/next space before the tactical action arrives."""
    global camera_last, camera_last_t
    target = tactical_space_pose(center, base_preset, height, lens)

    if camera_last is None:
        apply_camera_pose(target, 1 + round(float(t) * fps))
        camera_last = target
        camera_last_t = float(t)
        return

    start_pose = camera_last
    f0 = 1 + round(float(t) * fps)
    f1 = 1 + round((float(t) + float(duration)) * fps)
    span = max(1, f1 - f0)

    # Lead-space motion is slightly gentler than a chapter reframe.
    for u in (0.0, 0.22, 0.52, 0.78, 1.0):
        eased = u * u * (3.0 - 2.0 * u)
        fr = round(f0 + span * u)
        apply_camera_pose(mix_pose(start_pose, target, eased), fr)

    camera_last = target
    camera_last_t = float(t) + float(duration)


def set_player_visible(name, visible, frame):
    """Key body visibility for chapter changes; focus rings stay editorial."""
    prefix = name + "_"
    for obj in bpy.data.objects:
        if obj.name == name or obj.name.startswith(prefix):
            # Never auto-show a focus ring at a chapter boundary.
            if obj.name == name + "_RING":
                obj.hide_render = True
            else:
                obj.hide_render = not bool(visible)
            obj.keyframe_insert("hide_render", frame=frame)


def chapter_state(ev):
    """Reset one lesson chapter inside the same Blender scene.

    This is an editorial cut, not a new render: it can swap opponent units,
    restore a formation, and hand ball possession to the correct player.
    """
    fr = 1 + round(float(ev["t"]) * fps)
    visible = set(ev.get("visible_players", players.keys()))

    for name in players:
        set_player_visible(name, name in visible, fr)

    for name, pos in ev.get("positions", {}).items():
        if name not in players:
            continue
        obj = players[name]
        # One-frame state change so no unexplained sprint appears between
        # attack, defense and summary chapters.
        obj.location = (float(pos[0]), float(pos[1]), obj.location.z)
        key(obj, "location", fr)

    owner = ev.get("ball_owner")
    if owner:
        if owner not in players:
            raise ValueError(f"Unknown chapter ball owner: {owner}")
        o = players[owner]
        ball.location = (o.location.x, o.location.y, .37)
        key(ball, "location", fr)

    # Clear tactical emphasis at every chapter boundary.
    for r in rings.values():
        r.hide_render = True
        r.keyframe_insert("hide_render", frame=fr)


def focus_player(name, t):
    fr = 1 + round(t * fps)
    for n, r in rings.items():
        r.hide_render = n != name
        r.keyframe_insert(
            "hide_render",
            frame=fr,
        )


def focus_group(names, t):
    """Reveal one tactical line as a group: 4 -> 3 -> 2 -> 1."""
    fr = 1 + round(t * fps)
    active = set(names)
    for n, r in rings.items():
        r.hide_render = n not in active
        r.keyframe_insert(
            "hide_render",
            frame=fr,
        )


def animate_stride(name, f0, f1, strength=1.0):
    """Restrained locomotion with joint pivots and distance-aware cadence."""
    if f1 <= f0:
        return

    la = bpy.data.objects.get(name + "_LA")
    ra = bpy.data.objects.get(name + "_RA")
    ll = bpy.data.objects.get(name + "_LL")
    rl = bpy.data.objects.get(name + "_RL")
    torso = bpy.data.objects.get(name + "_TORSO")
    if not all((la, ra, ll, rl)):
        return

    arm = math.radians(18.0 * strength)
    leg = math.radians(22.0 * strength)
    span = max(1, f1 - f0)

    # One long tactical run needs several compact steps, not one slow swing.
    # At 12 fps this gives roughly 2-6 half-steps depending on run duration.
    half_steps = max(2, min(6, int(round(span / 3.0))))

    for idx in range(half_steps + 1):
        fr = round(f0 + span * (idx / half_steps))
        if idx == 0 or idx == half_steps:
            phase = 0.0
        else:
            phase = 1.0 if idx % 2 else -1.0

        la.rotation_euler[0] = arm * phase
        ra.rotation_euler[0] = -arm * phase
        ll.rotation_euler[0] = -leg * phase
        rl.rotation_euler[0] = leg * phase
        for limb in (la, ra, ll, rl):
            key(limb, "rotation_euler", fr)

    # A tiny forward body lean gives acceleration/weight without making the
    # miniature behave like a fully animated character.
    if torso is not None:
        torso.rotation_euler[0] = 0.0
        key(torso, "rotation_euler", f0)
        lean_fr = min(f1 - 1, f0 + max(1, round(span * .22)))
        torso.rotation_euler[0] = math.radians(-3.2 * strength)
        key(torso, "rotation_euler", lean_fr)
        recover_fr = max(lean_fr + 1, f1 - max(1, round(span * .18)))
        torso.rotation_euler[0] = math.radians(-1.0 * strength)
        key(torso, "rotation_euler", recover_fr)
        torso.rotation_euler[0] = 0.0
        key(torso, "rotation_euler", f1)


def move_player(name, target, t0, dur):
    o = players[name]
    f0 = 1 + round(t0 * fps)
    f1 = 1 + round((t0 + dur) * fps)

    sx, sy, sz = o.location.x, o.location.y, o.location.z
    tx, ty = float(target[0]), float(target[1])
    dx = tx - sx
    dy = ty - sy
    dist = math.hypot(dx, dy)

    # Anticipation first: turn toward the route just before the run begins.
    if dist > 1e-5:
        turn_fr = max(1, f0 - max(1, round(.14 * fps)))
        key(o, "rotation_euler", turn_fr)
        o.rotation_euler[2] = math.atan2(-dx, dy)
        key(o, "rotation_euler", f0)

    # Three spatial keys create a tiny rise/fall of the centre of mass.
    # The amount is deliberately small: tactical clarity first.
    key(o, "location", f0)

    fm = max(f0 + 1, round((f0 + f1) / 2))
    o.location = (
        sx + dx * .52,
        sy + dy * .52,
        sz + min(.075, .018 + dist * .0022),
    )
    key(o, "location", fm)

    o.location = (tx, ty, sz)
    key(o, "location", f1)

    stride_strength = min(1.0, max(.35, dist / 10.0))
    animate_stride(name, f0, f1, stride_strength)
    smooth_action(o)


def carry_ball(name, target, t0, dur):
    """Move the runner and ball together as one tactical carry."""
    o = players[name]
    sx, sy = o.location.x, o.location.y
    tx, ty = float(target[0]), float(target[1])
    dx, dy = tx - sx, ty - sy
    dist = max(1e-6, math.hypot(dx, dy))
    ux, uy = dx / dist, dy / dist
    lead = .46

    f0 = 1 + round(float(t0) * fps)
    f1 = 1 + round((float(t0) + float(dur)) * fps)
    fa = round(f0 + (f1 - f0) * .34)
    fb = round(f0 + (f1 - f0) * .68)

    ball.location = (sx + ux * lead, sy + uy * lead, .37)
    key(ball, "location", f0)
    ball.location = (sx + dx * .34 + ux * lead, sy + dy * .34 + uy * lead, .43)
    key(ball, "location", fa)
    ball.location = (sx + dx * .68 + ux * lead, sy + dy * .68 + uy * lead, .39)
    key(ball, "location", fb)
    ball.location = (tx + ux * lead, ty + uy * lead, .37)
    key(ball, "location", f1)
    smooth_action(ball)

    move_player(name, target, t0, dur)


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


def shot_ball(player, target, release, arrive, arc=.9):
    src = players[player]
    f0 = 1 + round(release * fps)
    f1 = 1 + round(arrive * fps)
    fm = max(f0 + 1, round((f0 + f1) / 2))

    # One compact kicking gesture on the shooting leg.
    rl = bpy.data.objects.get(player + "_RL")
    if rl is not None:
        fk0 = max(1, f0 - max(1, round(.15 * fps)))
        rl.rotation_euler[0] = math.radians(-10)
        key(rl, "rotation_euler", fk0)
        rl.rotation_euler[0] = math.radians(30)
        key(rl, "rotation_euler", f0)
        rl.rotation_euler[0] = 0.0
        key(rl, "rotation_euler", min(f1, f0 + max(1, round(.18 * fps))))

    ball.location = (src.location.x, src.location.y, .37)
    key(ball, "location", f0)

    ball.location = (
        (src.location.x + float(target[0])) / 2.0,
        (src.location.y + float(target[1])) / 2.0,
        .37 + float(arc),
    )
    key(ball, "location", fm)

    ball.location = (float(target[0]), float(target[1]), .37)
    key(ball, "location", f1)

    smooth_action(ball)


def add_triangle(ev):
    """Show three-player defensive protection as one tactical relationship."""
    names = ev["players"]
    if len(names) != 3:
        raise ValueError("triangle event requires exactly three players")

    f0 = 1 + round(float(ev["t"]) * fps)
    f1 = 1 + round((float(ev["t"]) + float(ev["duration"])) * fps)

    pts = []
    for n in names:
        o = players[n]
        pts.append((o.location.x, o.location.y))

    edges = [(0,1),(1,2),(2,0)]
    for idx,(a,b) in enumerate(edges):
        seg = line(
            "TRIANGLE_" + "_".join(names) + f"_{idx}",
            pts[a],
            pts[b],
            .045,
            m_ring,
            z=.29,
        )
        seg.hide_render = True
        seg.keyframe_insert("hide_render", frame=max(1, f0-1))
        seg.hide_render = False
        seg.keyframe_insert("hide_render", frame=f0)
        seg.hide_render = True
        seg.keyframe_insert("hide_render", frame=f1)


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

    if typ == "chapter_state":
        chapter_state(ev)

    elif typ == "camera":
        camera_key(
            ev["preset"],
            float(ev["t"]),
        )

    elif typ == "camera_glide":
        camera_glide(
            ev["preset"],
            float(ev["t"]),
            float(ev["duration"]),
        )

    elif typ == "camera_lead_space":
        camera_lead_space(
            ev["center"],
            float(ev["t"]),
            float(ev["duration"]),
            ev.get("base_preset", "between_lines"),
            ev.get("height"),
            ev.get("lens"),
        )

    elif typ == "focus":
        focus_player(
            ev["player"],
            float(ev["t"]),
        )

    elif typ == "focus_group":
        focus_group(
            ev["players"],
            float(ev["t"]),
        )

    elif typ in ("player_move", "defender_shift"):
        move_player(
            ev["player"],
            ev["to"],
            float(ev["t"]),
            float(ev["duration"]),
        )

    elif typ == "carry":
        carry_ball(
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

    elif typ == "shot":
        shot_ball(
            ev["from"],
            ev["to"],
            float(ev["release"]),
            float(ev["arrive"]),
            float(ev.get("arc", .9)),
        )

    elif typ == "triangle":
        add_triangle(ev)

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
