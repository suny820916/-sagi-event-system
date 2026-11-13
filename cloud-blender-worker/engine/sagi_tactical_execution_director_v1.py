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


def set_new_key_interpolation(mode):
    """Best-effort control for newly inserted keys; safe across Blender versions."""
    try:
        old = bpy.context.preferences.edit.keyframe_new_interpolation_type
        bpy.context.preferences.edit.keyframe_new_interpolation_type = mode
        return old
    except Exception:
        return None


def restore_new_key_interpolation(old):
    if old is None:
        return
    try:
        bpy.context.preferences.edit.keyframe_new_interpolation_type = old
    except Exception:
        pass


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


def event_start(ev):
    if "t" in ev:
        return float(ev["t"])
    if "release" in ev:
        return float(ev["release"])
    return 0.0


def event_end(ev):
    typ = ev.get("type")
    if typ in ("pass", "shot"):
        return float(ev.get("arrive", ev.get("release", event_start(ev))))
    if typ in ("player_move", "defender_shift", "dribble", "space"):
        return event_start(ev) + float(ev.get("duration", 0.0))
    return event_start(ev)


def validate_execution(config):
    """Validate tactical continuity before Blender spends time rendering."""
    errors = []
    warnings = []
    players_cfg = config.get("players", {})
    events = config.get("events", [])
    duration = float(config.get("duration_sec", 0.0))
    phases = config.get("execution_phases", [])
    initial_holder = config.get("initial_ball_holder")

    if not initial_holder:
        errors.append("initial_ball_holder is required")
    elif initial_holder not in players_cfg:
        errors.append(f"initial_ball_holder {initial_holder} is not a player")

    # Timeline must be chronological in the preset so cause/effect is explicit.
    starts = [event_start(ev) for ev in events]
    if starts != sorted(starts):
        errors.append("events are not sorted chronologically")

    # Every referenced player must exist, and every action must finish on screen.
    for i, ev in enumerate(events):
        typ = ev.get("type")
        for key_name in ("player", "from", "to"):
            ref = ev.get(key_name)
            if key_name == "to" and isinstance(ref, list):
                continue
            if key_name in ("player", "from", "to") and isinstance(ref, str):
                if ref not in players_cfg and not (typ == "shot" and key_name == "to"):
                    errors.append(f"event {i} references unknown player {ref}")

        if typ == "relation_camera":
            subjects = ev.get("subjects", [])
            if len(subjects) < 2:
                errors.append(f"event {i} relation_camera needs at least two subjects")
            for subject in subjects:
                if subject not in players_cfg:
                    errors.append(f"event {i} relation_camera references unknown player {subject}")

        if event_end(ev) > duration + 1e-6:
            errors.append(
                f"event {i} ({typ}) ends at {event_end(ev):.2f}s "
                f"after duration {duration:.2f}s"
            )

        if typ in ("pass", "shot"):
            release = float(ev.get("release", 0))
            arrive = float(ev.get("arrive", 0))
            if arrive <= release:
                errors.append(f"event {i} ({typ}) has invalid ball timing")

    # Possession chain: no teleporting the ball between unrelated players.
    holder = initial_holder
    ball_chain = []
    for i, ev in enumerate(events):
        typ = ev.get("type")
        if typ == "pass":
            src = ev.get("from")
            dst = ev.get("to")
            if holder and src != holder:
                errors.append(
                    f"possession break before event {i}: "
                    f"expected {holder}, pass starts from {src}"
                )
            holder = dst
            ball_chain.append(f"{src}->{dst}")
        elif typ == "shot":
            src = ev.get("from")
            if holder and src != holder:
                errors.append(
                    f"possession break before shot event {i}: "
                    f"expected {holder}, shot starts from {src}"
                )
            ball_chain.append(f"{src}->TARGET")

        elif typ == "dribble":
            src = ev.get("player")
            if holder and src != holder:
                errors.append(
                    f"possession break before dribble event {i}: "
                    f"expected {holder}, dribble belongs to {src}"
                )
            ball_chain.append(f"{src}->DRIBBLE")

    # Each declared phase must contain a real tactical action, not only a camera cue.
    phase_report = []
    for phase in phases:
        p0 = float(phase["from"])
        p1 = float(phase["to"])
        phase_events = [
            ev for ev in events
            if event_start(ev) >= p0 - 1e-6 and event_start(ev) < p1 - 1e-6
        ]
        tactical_events = [
            ev for ev in phase_events
            if ev.get("type") not in ("camera", "camera_dna", "relation_camera", "focus", "space")
        ]
        defender_events = [
            ev for ev in phase_events if ev.get("type") == "defender_shift"
        ]
        if not tactical_events:
            errors.append(f"phase {phase['name']} has no tactical action")
        if config.get("require_defensive_reaction", False) and not defender_events:
            warnings.append(f"phase {phase['name']} has no visible defensive reaction")
        phase_report.append({
            "name": phase["name"],
            "from": p0,
            "to": p1,
            "event_count": len(phase_events),
            "tactical_event_count": len(tactical_events),
            "defender_reaction_count": len(defender_events),
        })

    last_action_end = max(
        [event_end(ev) for ev in events if ev.get("type") not in ("camera", "camera_dna", "relation_camera", "focus", "space")]
        or [0.0]
    )
    completion_hold = max(0.0, duration - last_action_end)
    if completion_hold > 1.5:
        warnings.append(
            f"post-execution hold is {completion_hold:.2f}s; check for dead time"
        )

    report = {
        "version": config.get("version"),
        "director_mode": config.get("director_mode"),
        "duration_sec": duration,
        "initial_ball_holder": initial_holder,
        "final_ball_holder": holder,
        "ball_chain": ball_chain,
        "phase_report": phase_report,
        "last_action_end_sec": round(last_action_end, 3),
        "completion_hold_sec": round(completion_hold, 3),
        "errors": errors,
        "warnings": warnings,
        "valid": not errors,
    }
    return report


def predicted_player_pos(name, t):
    """Predict a player's XY position from preset movement events at time t."""
    base = cfg["players"][name]["pos"]
    x, y = float(base[0]), float(base[1])

    for ev in cfg.get("events", []):
        if ev.get("type") not in ("player_move", "defender_shift", "dribble"):
            continue
        if ev.get("player") != name:
            continue

        t0 = float(ev["t"])
        dur = max(1e-6, float(ev["duration"]))
        t1 = t0 + dur
        tx, ty = float(ev["to"][0]), float(ev["to"][1])

        if t < t0:
            break
        if t >= t1:
            x, y = tx, ty
            continue

        alpha = max(0.0, min(1.0, (t - t0) / dur))
        # Match the spatial intent closely enough for framing; exact Bezier
        # easing is less important than keeping all relationship subjects visible.
        return (
            x + (tx - x) * alpha,
            y + (ty - y) * alpha,
        )

    return (x, y)


execution_report = validate_execution(cfg)
report_path = os.path.join(out_dir, "execution_report.json")
with open(report_path, "w", encoding="utf-8") as f:
    json.dump(execution_report, f, ensure_ascii=False, indent=2)

print("SAGI_EXECUTION_REPORT", json.dumps(execution_report, ensure_ascii=False))

if execution_report["errors"]:
    raise RuntimeError(
        "TACTICAL_EXECUTION_INVALID: " + "; ".join(execution_report["errors"])
    )

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

m_floor = material(
    "TACTICAL_FLOOR",
    hex_rgba(pal.get("tactical_floor", "#080A0B")),
    rough=.88,
)
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

# Continuous tactical board beneath the regulation pitch.
# It removes hard black voids when a structure-preserving camera pulls wider,
# while keeping all football markings confined to the real pitch.
cube("TACTICAL_FLOOR", (0, 5, -.23), (78, 105, .045), m_floor)

# Floating pitch
cube("PITCH", (0, 0, 0), (40, 60, .18), m_pitch)

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
    root.scale = (1.56, 1.56, 1.56)

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

initial_ball_holder = cfg.get("initial_ball_holder", "GK")
ball_owner = players[initial_ball_holder]
ball = sphere(
    "BALL",
    (
        ball_owner.location.x,
        ball_owner.location.y,
        .37,
    ),
    .28,
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
# Lock horizontal sensor fit so 9:16 framing math is deterministic.
# AUTO can narrow the horizontal field in portrait renders and crop subjects.
cam.data.sensor_fit = "HORIZONTAL"

camera_dna = {
    # V2 relation framing: preserve the tactical angle but crop much tighter.
    # The pitch is context; the relationship between players is the subject.
    "receive": {
        "loc": (2,-17,62), "target": (0,-10,0), "lens": 70,
        "lead": .00, "settle": .00,
    },
    "expand": {
        "loc": (2,-13,76), "target": (0,-3,0), "lens": 68,
        "lead": .22, "settle": .16,
    },
    "half_space": {
        # Keep passer + receiver + nearest midfield defenders in the same frame.
        "loc": (4,-5,74), "target": (3,3,0), "lens": 68,
        "lead": .24, "settle": .16,
    },
    "overlap": {
        # Centre the actual overlap triangle: carrier + fullback + shifted defender.
        # At the key moment their tactical centroid is around x=17, y=10.
        "loc": (17,3,78), "target": (17,10,0), "lens": 68,
        "lead": .24, "settle": .16,
    },
    "switch": {
        "loc": (2,14,78), "target": (0,26,0), "lens": 66,
        "lead": .26, "settle": .18,
    },
    "complete": {
        "loc": (-1,24,72), "target": (-3,38,0), "lens": 68,
        "lead": .18, "settle": .20,
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


def camera_dna_key(cue, t):
    """Execution camera: preserve the tactical relation, reframe only when required."""
    global camera_last, camera_last_t
    p = camera_dna[cue]
    t = float(t)
    cue_fr = 1 + round(t * fps)

    if camera_last is None or t <= .001:
        apply_camera_pose(p, cue_fr)
        camera_last = p
        camera_last_t = t
        return

    lead = float(p.get("lead", .28))
    settle = float(p.get("settle", .20))
    start_t = max(camera_last_t, t - lead)
    start_fr = 1 + round(start_t * fps)
    end_fr = 1 + round((t + settle) * fps)

    # Hold the previous composition until just before the tactical event.
    apply_camera_pose(camera_last, start_fr)
    # Complete the reframe just after the event begins, then stop moving.
    apply_camera_pose(p, end_fr)

    camera_last = p
    camera_last_t = t + settle


FIELD_SCOPE_BOUNDS = {
    # Tactical board regions. These are not visual decorations: each rectangle
    # represents the minimum pitch context needed to understand a phase.
    "FULL_PITCH": (-34.0, 34.0, -52.5, 52.5),
    "DEFENSIVE_HALF_PLUS_MIDFIELD": (-30.0, 30.0, -48.0, 12.0),
    "CENTRAL_THREE_QUARTERS": (-30.0, 30.0, -34.0, 34.0),
    # V10.1 Teactics-style tactical scopes: wide enough to explain the
    # relationship, but not so wide that every semi-global view becomes a
    # near-full-pitch shot in 9:16.
    "CENTRAL_MIDFIELD_WIDE": (-26.0, 26.0, -20.0, 22.0),
    "CENTRAL_ATTACK_RELATION": (-17.0, 18.0, -4.0, 27.0),
    "RIGHT_OVERLAP_RELATION": (5.0, 32.0, 0.0, 34.0),
    "ATTACKING_WIDTH_ZONE": (-22.0, 32.0, 9.0, 46.0),
    "MIDFIELD_ZONE": (-18.0, 18.0, -12.0, 26.0),
    "RIGHT_CHANNEL_ZONE": (0.0, 32.0, -6.0, 32.0),
    "ATTACKING_TWO_THIRDS": (-30.0, 30.0, 0.0, 52.5),
    "FINAL_THIRD": (-24.0, 24.0, 18.0, 54.0),
}


def field_scope_points(name):
    bounds = FIELD_SCOPE_BOUNDS.get(name)
    if not bounds:
        return []
    x0, x1, y0, y1 = bounds
    return [(x0,y0), (x0,y1), (x1,y0), (x1,y1)]


def relation_camera_pose(
    subjects,
    start_t,
    focus_t,
    lens=64.0,
    min_z=64.0,
    margin=1.20,
    shot_scale=None,
    field_scope=None,
):
    """Keep full trajectory in frame, but centre on the current tactical relation."""
    start_t = float(start_t)
    focus_t = float(focus_t)

    # A local Teactics-style relation shot should not be forced to include the
    # entire run from its origin. Enter the close tactical view only when the
    # relationship is forming; structural shots still preserve the full route.
    framing_start_t = start_t
    if str(shot_scale or "") in ("RELATION", "RESULT_RELATION"):
        scale_cfg = cfg.get("scale_script", {})
        history_sec = float(scale_cfg.get("local_relation_history_sec", .68))
        framing_start_t = max(start_t, focus_t - history_sec)

    mid_t = (framing_start_t + focus_t) * .5

    # Trajectory protects framing completeness inside the chosen shot scale.
    trajectory_pts = []
    # Focus positions define where the tactical story actually is now.
    focus_pts = []
    for name in subjects:
        trajectory_pts.append(predicted_player_pos(name, framing_start_t))
        trajectory_pts.append(predicted_player_pos(name, mid_t))
        fp = predicted_player_pos(name, focus_t)
        trajectory_pts.append(fp)
        focus_pts.append(fp)

    xs = [p[0] for p in trajectory_pts]
    ys = [p[1] for p in trajectory_pts]

    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span_x = max(4.0, max_x - min_x)
    span_y = max(4.0, max_y - min_y)

    # Do NOT centre on the entire start-to-end trajectory: that can pull the
    # camera backwards while the attack has already moved forward. Centre on
    # the relationship at focus_t, while still using the whole trajectory for
    # safe framing bounds.
    fxs = [p[0] for p in focus_pts]
    fys = [p[1] for p in focus_pts]
    relation_cx = (min(fxs) + max(fxs)) * .5
    relation_cy = (min(fys) + max(fys)) * .5

    scope_pts = field_scope_points(field_scope)
    if scope_pts:
        sxs = [p[0] for p in scope_pts]
        sys = [p[1] for p in scope_pts]
        scope_cx = (min(sxs) + max(sxs)) * .5
        scope_cy = (min(sys) + max(sys)) * .5
    else:
        scope_cx, scope_cy = relation_cx, relation_cy

    # Teactics-style scale grammar:
    # structural shots let the pitch region lead composition; relation shots
    # let the player relationship lead while still retaining its tactical zone.
    scope_weight = {
        "STRUCTURE": .58,
        "WIDE_STRUCTURE": .68,
        "RELATION": .18,
        "RESULT_RELATION": .30,
    }.get(str(shot_scale or ""), .22)

    cx = relation_cx * (1.0 - scope_weight) + scope_cx * scope_weight
    cy = relation_cy * (1.0 - scope_weight) + scope_cy * scope_weight

    # Structural shots must genuinely show their wider pitch region.
    # Relation shots use the named field scope only to orient the composition;
    # forcing all four scope corners into a close tactical shot would shrink
    # players back into chess pieces.
    framing_pts = list(trajectory_pts)
    if str(shot_scale or "") in ("STRUCTURE", "WIDE_STRUCTURE"):
        framing_pts.extend(scope_pts)

    # Lens-aware framing for 9:16 portrait.
    # The old empirical factors pushed wide tactical relations far too high,
    # making players read like chess pieces. Compute the height from the
    # actual horizontal field of view instead.
    sensor_width = float(getattr(cam.data, "sensor_width", 36.0))
    lens = max(20.0, float(lens))
    tan_half_h = sensor_width / (2.0 * lens)
    aspect_h_over_w = max(1.0, float(h) / max(1.0, float(w)))
    tan_half_v = tan_half_h * aspect_h_over_w

    # Target may intentionally sit closer to the tactical relation than the
    # centre of the field scope, so fit by maximum distance from the target,
    # not by bbox span alone.
    max_dx = max([abs(p[0] - cx) for p in framing_pts] or [span_x * .5])
    max_dy = max([abs(p[1] - cy) for p in framing_pts] or [span_y * .5])
    z_x = (max_dx * float(margin)) / max(1e-6, tan_half_h)
    z_y = (max_dy * float(margin)) / max(1e-6, tan_half_v)
    z = max(float(min_z), z_x, z_y)

    # Keep the camera nearly tactical-top-down, but retain enough angle to
    # perceive miniature bodies and running direction.
    tilt_back = max(4.5, min(7.0, span_y * .16))

    continuity_cfg = cfg.get("camera_continuity", {})
    return {
        "loc": (cx, cy - tilt_back, z),
        "target": (cx, cy, 0),
        "lens": float(lens),
        "lead": float(continuity_cfg.get("lead_sec", .34)),
        "settle": float(continuity_cfg.get("settle_sec", .32)),
        "shot_scale": shot_scale,
        "field_scope": field_scope,
    }


def relation_camera_key(
    subjects,
    t,
    focus_t=None,
    lens=64.0,
    min_z=64.0,
    margin=1.20,
    shot_scale=None,
    field_scope=None,
):
    """Reframe from the actual tactical relationship instead of fixed coordinates."""
    global camera_last, camera_last_t
    t = float(t)
    focus_t = float(t if focus_t is None else focus_t)
    p = relation_camera_pose(
        subjects, t, focus_t, lens, min_z, margin, shot_scale, field_scope
    )

    # Spatial continuity: in an upfield attack, don't let the camera centre
    # suddenly jump backwards just because a supporting runner started deeper.
    continuity_cfg = cfg.get("camera_continuity", {})
    if camera_last is not None and continuity_cfg.get("preserve_forward_progression", False):
        max_back = float(continuity_cfg.get("max_backward_target_m", 1.5))
        prev_y = float(camera_last["target"][1])
        new_y = float(p["target"][1])
        min_allowed_y = prev_y - max_back
        if new_y < min_allowed_y:
            dy = min_allowed_y - new_y
            p["target"] = (p["target"][0], min_allowed_y, p["target"][2])
            p["loc"] = (p["loc"][0], p["loc"][1] + dy, p["loc"][2])

    # Camera-rail scale continuity:
    # zoom OUT immediately when the structure needs more room, but zoom IN only
    # gradually from phase to phase. This keeps the tactical space coherent.
    if camera_last is not None and continuity_cfg.get("preserve_scale_continuity", False):
        prev_scale = camera_last.get("shot_scale")
        new_scale = p.get("shot_scale")
        deliberate_scale_change = (
            continuity_cfg.get("allow_scale_reset_on_shot_scale_change", False)
            and prev_scale
            and new_scale
            and prev_scale != new_scale
        )

        # Teactics-style grammar: continuity is preserved inside one tactical
        # scale, but a deliberate STRUCTURE -> RELATION or RELATION -> WIDE
        # change is allowed to reset framing decisively.
        if not deliberate_scale_change:
            prev_z = float(camera_last["loc"][2])
            new_z = float(p["loc"][2])
            max_zoom_in = float(continuity_cfg.get("max_zoom_in_per_phase_m", 8.0))
            min_allowed_z = max(1.0, prev_z - max_zoom_in)
            if new_z < min_allowed_z:
                p["loc"] = (p["loc"][0], p["loc"][1], min_allowed_z)

    if camera_last is None or t <= .001:
        apply_camera_pose(p, 1 + round(t * fps))
        camera_last = p
        camera_last_t = t
        return

    lead = float(p.get("lead", .24))
    settle = float(p.get("settle", .16))
    start_t = max(camera_last_t, t - lead)
    start_fr = 1 + round(start_t * fps)
    end_fr = 1 + round((t + settle) * fps)

    apply_camera_pose(camera_last, start_fr)
    apply_camera_pose(p, end_fr)

    camera_last = p
    camera_last_t = t + settle


def camera_key(preset, t):
    # Backward compatibility for old presets; new Golden Sample uses camera_dna.
    legacy = {
        "shape": "receive",
        "midfield": "receive",
        "between_lines": "half_space",
        "width": "switch",
        "relation": "half_space",
        "result": "switch",
        "finish": "complete",
        "complete": "complete",
    }
    camera_dna_key(legacy.get(preset, "receive"), t)


def focus_player(name, t):
    fr = 1 + round(t * fps)
    for n, r in rings.items():
        r.hide_render = n != name
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


def move_player(name, target, t0, dur, carry_ball=False):
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

    if carry_ball:
        # Explicit ball-carrying state. The ball follows the runner instead of
        # teleporting from the reception point to the eventual shot/pass point.
        if dist > 1e-5:
            ux, uy = dx / dist, dy / dist
        else:
            ux, uy = 0.0, 1.0
        lead = .34

        old_interp = set_new_key_interpolation("LINEAR")
        ball.location = (sx + ux * .10, sy + uy * .10, .37)
        key(ball, "location", f0)
        ball.location = (
            sx + dx * .52 + ux * lead,
            sy + dy * .52 + uy * lead,
            .37,
        )
        key(ball, "location", fm)
        ball.location = (tx + ux * .12, ty + uy * .12, .37)
        key(ball, "location", f1)
        restore_new_key_interpolation(old_interp)

    stride_strength = min(1.0, max(.35, dist / 10.0))
    animate_stride(name, f0, f1, stride_strength)
    smooth_action(o)


def yaw_toward(src_xy, dst_xy):
    dx = float(dst_xy[0]) - float(src_xy[0])
    dy = float(dst_xy[1]) - float(src_xy[1])
    if abs(dx) + abs(dy) <= 1e-6:
        return None
    return math.atan2(-dx, dy)


def next_action_target(name, after_t):
    """Return the next tactical destination for a player after receiving."""
    after_t = float(after_t)
    for ev in cfg.get("events", []):
        typ = ev.get("type")

        if typ == "pass" and ev.get("from") == name:
            start_t = float(ev.get("release", ev.get("t", 0)))
            if start_t <= after_t + .04:
                continue
            target_name = ev.get("to")
            return (
                predicted_player_pos(target_name, float(ev.get("arrive", start_t))),
                start_t,
            )

        if typ == "dribble" and ev.get("player") == name:
            start_t = float(ev.get("t", 0))
            if start_t <= after_t + .04:
                continue
            return (
                (float(ev["to"][0]), float(ev["to"][1])),
                start_t,
            )

        if typ == "shot" and ev.get("from") == name:
            start_t = float(ev.get("release", ev.get("t", 0)))
            if start_t <= after_t + .04:
                continue
            return (
                (float(ev["to"][0]), float(ev["to"][1])),
                start_t,
            )

    return (None, None)


def pass_ball(a, b, release, arrive):
    aa = players[a]
    bb = players[b]
    release = float(release)
    arrive = float(arrive)
    f0 = 1 + round(release * fps)
    f1 = 1 + round(arrive * fps)

    # Use timeline positions, not the object's eventual final transform.
    # This keeps ball flight attached to where players really are at release/arrival.
    src_xy = predicted_player_pos(a, release)
    dst_xy = predicted_player_pos(b, arrive)

    # Passer opens toward the target just before release.
    pass_yaw = yaw_toward(src_xy, dst_xy)
    if pass_yaw is not None:
        turn_fr = max(1, f0 - max(1, round(.12 * fps)))
        key(aa, "rotation_euler", turn_fr)
        aa.rotation_euler[2] = pass_yaw
        key(aa, "rotation_euler", f0)

    # Receiver checks toward the incoming ball before contact.
    prep_fr = max(f0 + 1, f1 - max(1, round(.18 * fps)))
    receive_yaw = yaw_toward(dst_xy, src_xy)
    if receive_yaw is not None:
        bb.rotation_euler[2] = receive_yaw
        key(bb, "rotation_euler", prep_fr)
        key(bb, "rotation_euler", f1)

    # Ball travels decisively between actual timeline positions.
    old_interp = set_new_key_interpolation("LINEAR")
    ball.location = (src_xy[0], src_xy[1], .37)
    key(ball, "location", f0)

    ball.location = (dst_xy[0], dst_xy[1], .37)
    key(ball, "location", f1)

    # Compact first touch: continue the incoming line a fraction, then keep
    # possession ready for the next action. This avoids a dead "ball stops"
    # feeling without turning the clip into character animation.
    next_target, next_t = next_action_target(b, arrive)
    gap = None if next_t is None else float(next_t) - arrive
    if gap is None or gap > .22:
        dx = dst_xy[0] - src_xy[0]
        dy = dst_xy[1] - src_xy[1]
        dist = math.hypot(dx, dy)
        if dist > 1e-5:
            ux, uy = dx / dist, dy / dist
            touch_fr = min(scene.frame_end, f1 + max(1, round(.11 * fps)))
            ball.location = (
                dst_xy[0] + ux * .16,
                dst_xy[1] + uy * .16,
                .37,
            )
            key(ball, "location", touch_fr)
    restore_new_key_interpolation(old_interp)

    # Instead of recovering to an arbitrary old yaw, the receiver turns
    # directly toward the next tactical action: pass, dribble, or shot.
    if next_target is not None:
        next_yaw = yaw_toward(dst_xy, next_target)
        if next_yaw is not None:
            latest_turn_t = max(arrive + .12, float(next_t) - .08)
            turn_done_t = min(arrive + .34, latest_turn_t)
            turn_done_fr = min(
                scene.frame_end,
                max(f1 + 1, 1 + round(turn_done_t * fps)),
            )
            bb.rotation_euler[2] = next_yaw
            key(bb, "rotation_euler", turn_done_fr)

    smooth_action(ball)


def shot_ball(player, target, release, arrive, arc=.9):
    src = players[player]
    release = float(release)
    arrive = float(arrive)
    f0 = 1 + round(release * fps)
    f1 = 1 + round(arrive * fps)
    fm = max(f0 + 1, round((f0 + f1) / 2))
    src_xy = predicted_player_pos(player, release)
    target_xy = (float(target[0]), float(target[1]))

    shot_yaw = yaw_toward(src_xy, target_xy)
    if shot_yaw is not None:
        turn_fr = max(1, f0 - max(1, round(.14 * fps)))
        key(src, "rotation_euler", turn_fr)
        src.rotation_euler[2] = shot_yaw
        key(src, "rotation_euler", f0)

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

    ball.location = (src_xy[0], src_xy[1], .37)
    key(ball, "location", f0)

    ball.location = (
        (src_xy[0] + target_xy[0]) / 2.0,
        (src_xy[1] + target_xy[1]) / 2.0,
        .37 + float(arc),
    )
    key(ball, "location", fm)

    ball.location = (target_xy[0], target_xy[1], .37)
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


first_camera_event = next(
    (
        ev for ev in cfg.get("events", [])
        if ev.get("type") in ("camera", "camera_dna", "relation_camera")
    ),
    None,
)
if first_camera_event is None or float(first_camera_event.get("t", 0)) > 0.001:
    camera_dna_key("receive", 0)

for ev in cfg.get("events", []):
    typ = ev.get("type")

    if typ == "camera":
        camera_key(
            ev["preset"],
            float(ev["t"]),
        )

    elif typ == "camera_dna":
        camera_dna_key(
            ev["cue"],
            float(ev["t"]),
        )

    elif typ == "relation_camera":
        relation_camera_key(
            ev["subjects"],
            float(ev["t"]),
            ev.get("focus_t"),
            float(ev.get("lens", 64)),
            float(ev.get("min_z", 64)),
            float(ev.get("margin", 1.20)),
            ev.get("shot_scale"),
            ev.get("field_scope"),
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
            False,
        )

    elif typ == "dribble":
        move_player(
            ev["player"],
            ev["to"],
            float(ev["t"]),
            float(ev["duration"]),
            True,
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
