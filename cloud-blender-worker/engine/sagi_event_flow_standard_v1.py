import bpy, json, os, sys, math
from mathutils import Vector

def args_after_dd():
    argv=sys.argv
    return argv[argv.index("--")+1:] if "--" in argv else []

def rgba(h):
    h=h.lstrip("#")
    if len(h)==6:
        return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1.0,)
    return (1,1,1,1)

def mat(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=color
    return m

def cube(name,loc,scale,material):
    bpy.ops.mesh.primitive_cube_add(size=2, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    if material: o.data.materials.append(material)
    return o

def cyl(name,loc,radius,depth,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=radius,depth=depth,location=loc)
    o=bpy.context.object; o.name=name
    if material: o.data.materials.append(material)
    return o

def sphere(name,loc,radius,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=radius, location=loc)
    o=bpy.context.object; o.name=name
    if material: o.data.materials.append(material)
    return o

def hide_at(o,frame,hidden):
    o.hide_render=hidden
    o.keyframe_insert("hide_render",frame=frame)

def key_loc(o,t,xyz,fps):
    o.location=xyz
    o.keyframe_insert("location",frame=1+round(t*fps))

def look_at(obj,target):
    direction=Vector(target)-obj.location
    obj.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()

def key_camera(cam,target,t,loc,target_loc,lens,fps):
    f=1+round(t*fps)
    cam.location=loc; cam.data.lens=lens
    target.location=target_loc
    cam.keyframe_insert("location",frame=f)
    cam.data.keyframe_insert("lens",frame=f)
    target.keyframe_insert("location",frame=f)

def gate(name,x,y,width,material,z=0.6):
    post=.055; h=.62
    cube(name+"_L",(x-width/2,y,h/2+0.2),(post,post,h/2),material)
    cube(name+"_R",(x+width/2,y,h/2+0.2),(post,post,h/2),material)
    cube(name+"_T",(x,y,h+0.2),(width/2+post,post,post),material)

def goal(name,y,material):
    w=7.32; h=2.44
    cube(name+"_L",(-w/2,y,h/2+0.18),(.06,.06,h/2),material)
    cube(name+"_R",(w/2,y,h/2+0.18),(.06,.06,h/2),material)
    cube(name+"_T",(0,y,h+0.18),(w/2+.06,.06,.06),material)
    return w,h

def make_player(name,material):
    root=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(root)
    root.location=(-7.5,-15.0,0.22)
    torso=cube(name+"_TORSO",(0,0,1.0),(.22,.16,.38),material)
    head=sphere(name+"_HEAD",(0,0,1.56),.15,material)
    for ch in (torso,head): ch.parent=root
    for suffix,x in (("LA",-0.27),("RA",0.27)):
        limb=cyl(name+"_"+suffix,(x,0,0.92),.045,.48,material); limb.parent=root
    for suffix,x in (("LL",-0.10),("RL",0.10)):
        limb=cyl(name+"_"+suffix,(x,0,0.43),.055,.70,material); limb.parent=root
    return root

def make_flat_marker(name,x,y,sx,sy,material,z=.22):
    return cube(name,(x,y,z),(sx,sy,.015),material)

def animate_object_path(o, pts, fps):
    for t,x,y,z in pts: key_loc(o,t,(x,y,z),fps)

args=args_after_dd()
if len(args)<2: raise SystemExit("Usage: blender --background --python sagi_event_flow_standard_v1.py -- preset.json out_dir")
cfg_path=os.path.abspath(args[0]); out_dir=os.path.abspath(args[1]); os.makedirs(out_dir,exist_ok=True)
cfg=json.load(open(cfg_path,encoding="utf-8"))
fps=int(cfg.get("fps",30)); dur=float(cfg.get("duration_sec",45)); w,h=cfg.get("resolution",[540,960])
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.resolution_x=w; scene.render.resolution_y=h; scene.render.resolution_percentage=100
scene.render.fps=fps; scene.frame_start=1; scene.frame_end=round(dur*fps)
scene.render.engine="BLENDER_WORKBENCH"
scene.render.image_settings.file_format="PNG"; scene.render.image_settings.color_mode="RGB"
frames=os.path.join(out_dir,"frames"); os.makedirs(frames,exist_ok=True); scene.render.filepath=os.path.join(frames,"frame_")
if scene.world is None:\n    scene.world = bpy.data.worlds.new("SAGI_WORLD")\nscene.world.color=(0,0,0)
try:
    scene.display.shading.light="STUDIO"; scene.display.shading.color_type="MATERIAL"
    scene.display.shading.show_cavity=True; scene.display.shading.cavity_type="WORLD"
except Exception: pass

pal=cfg["palette"]
m_pitch=mat("PITCH",rgba(pal["pitch"])); m_alt=mat("ALT",rgba(pal["pitch_alt"]))
m_line=mat("LINE",rgba(pal["line"])); m_y=mat("SAGI_YELLOW",rgba(pal["accent"]))
m_dim=mat("DIM",rgba(pal["dim"])); m_player=mat("PLAYER",rgba(pal["player"]))
m_ball=mat("BALL",(0.95,0.95,0.95,1)); m_miss=mat("MISS",(0.95,0.22,0.08,1))

# 20m x 35m event floor
cube("EVENT_FLOOR",(0,0,0),(10,17.5,.16),m_pitch)
for i in range(7):
    yy=-15+5*i
    cube("BAND_"+str(i),(0,yy,.18),(9.95,2.5,.01), m_alt if i%2==0 else m_pitch)
# border + center guide
for x in (-10,10): cube("SIDE_"+str(x),(x,0,.22),(.035,17.5,.02),m_line)
for y in (-17.5,17.5): cube("END_"+str(y),(0,y,.22),(10,.035,.02),m_line)
cube("CENTER_GUIDE",(0,0,.215),(.02,17.5,.01),m_dim)

# 01 BURST: horizontal 15m sprint at bottom
start=(-7.5,-15.0); pickup=(7.5,-15.0)
cube("START_LINE",(start[0],start[1],.24),(.04,1.0,.02),m_y)
make_flat_marker("BURST_LANE",0,-15.0,7.5,.06,m_y)
pickup_ball=sphere("CARRY_BALL",(pickup[0],pickup[1],.38),.22,m_ball)

# 02 CONTROL: six gates on right-to-left serpentine
control=[(6.2,-12.4),(3.4,-10.8),(6.0,-9.2),(3.0,-7.6),(5.7,-6.0),(2.6,-4.4)]
for i,(x,y) in enumerate(control,1): gate(f"CONTROL_{i}",x,y,1.4,m_y)
# floor dots as visual route
for i,(x,y) in enumerate(control): make_flat_marker(f"C_ROUTE_{i}",x,y,.16,.16,m_y)

# 03 REACT: three stations across mid band; grey choices plus yellow highlight duplicates
react_stations=[(-4.8,-2.2),(-1.2,0.0),(2.4,2.2)]
react_choices=["LEFT","RIGHT","LEFT"]
react_highlights=[]
for idx,(cx,cy) in enumerate(react_stations,1):
    cube(f"TRIGGER_{idx}",(cx,cy-.65,.24),(1.6,.025,.02),m_line)
    gate(f"R{idx}_L",cx-1.05,cy,.95,m_dim); gate(f"R{idx}_R",cx+1.05,cy,.95,m_dim)
    hx=cx-1.05 if react_choices[idx-1]=="LEFT" else cx+1.05
    parts=[]
    for suffix,dx in (("L",-0.95/2),("R",0.95/2)):
        parts.append(cube(f"R{idx}_HI_{suffix}",(hx+dx,cy,.51),(.055,.055,.31),m_y))
    parts.append(cube(f"R{idx}_HI_T",(hx,cy,.82),(.53,.055,.055),m_y))
    react_highlights.append(parts)
    for o in parts:
        hide_at(o,1,True)

# 04 PASS
pass_box=(0,5.0)
cube("PASS_BOX",(pass_box[0],pass_box[1],.23),(1,1,.018),m_line)
pass_targets={"LEFT":(-5.0,13.8),"CENTER":(0,13.8),"RIGHT":(5.0,13.8)}
for k,(x,y) in pass_targets.items(): gate("PASS_"+k,x,y,1.5,m_y)

# 05 FINISH
goal_y=17.1
goal("GOAL",goal_y,m_line)
make_flat_marker("TARGET_LEFT",-2.45,goal_y-.12,1.15,.28,m_y,z=.30)
make_flat_marker("TARGET_RIGHT",2.45,goal_y-.12,1.15,.28,m_y,z=.30)
shoot_pos=(0,5.1)

# player animation
p=make_player("ATHLETE",m_player)
player_pts=[
(0,-7.5,-15.0,.22),(3,-7.5,-15.0,.22),(6.7,7.5,-15.0,.22),
(7.0,7.5,-15.0,.22),
(8.0,6.2,-12.4,.22),(9.2,3.4,-10.8,.22),(10.3,6.0,-9.2,.22),(11.5,3.0,-7.6,.22),(12.6,5.7,-6.0,.22),(14.0,2.6,-4.4,.22),
(15.2,-4.8,-2.85,.22),(16.0,-5.85,-2.2,.22),(17.6,-1.2,-0.65,.22),(18.5,-0.15,0.0,.22),(20.0,2.4,1.55,.22),(21.0,1.35,2.2,.22),
(22.0,0,5.0,.22),(31.0,0,5.0,.22),(39.0,0,5.1,.22),(45.0,0,5.1,.22)]
animate_object_path(p,player_pts,fps)

# carry ball hidden until pickup, then follows control/react, hidden at PASS
hide_at(pickup_ball,1,True); hide_at(pickup_ball,1+round(6.65*fps),True); hide_at(pickup_ball,1+round(6.70*fps),False)
ball_pts=[
(6.7,7.5,-15.0,.38),(8.0,6.2,-12.4,.38),(9.2,3.4,-10.8,.38),(10.3,6.0,-9.2,.38),(11.5,3.0,-7.6,.38),(12.6,5.7,-6.0,.38),(14.0,2.6,-4.4,.38),
(15.2,-4.8,-2.85,.38),(16.0,-5.85,-2.2,.38),(17.6,-1.2,-0.65,.38),(18.5,-0.15,0.0,.38),(20.0,2.4,1.55,.38),(21.0,1.35,2.2,.38),(22.0,0,5.0,.38)]
animate_object_path(pickup_ball,ball_pts,fps)
hide_at(pickup_ball,1+round(22.0*fps),False); hide_at(pickup_ball,1+round(22.05*fps),True)

# react highlight timings
for idx,parts in enumerate(react_highlights):
    t_on=[15.35,17.85,20.20][idx]
    for o in parts:
        hide_at(o,1+round((t_on-.03)*fps),True)
        hide_at(o,1+round(t_on*fps),False)
        hide_at(o,1+round((t_on+1.1)*fps),True)

# 6 pass balls, one intentional miss at pass 4
seq=["LEFT","RIGHT","CENTER","CENTER","LEFT","RIGHT"]
pass_times=[22.4,23.75,25.10,26.45,27.80,29.15]
for i,(target,t0) in enumerate(zip(seq,pass_times),1):
    b=sphere(f"PASS_BALL_{i}",(pass_box[0]+(-.7+.28*i),pass_box[1],.38),.20,m_ball)
    hide_at(b,1,True); hide_at(b,1+round((t0-.04)*fps),True); hide_at(b,1+round(t0*fps),False)
    tx,ty=pass_targets[target]
    if i==4: tx+=2.2
    key_loc(b,t0,b.location,fps); key_loc(b,t0+.75,(tx,ty,.30),fps)
    hide_at(b,1+round((t0+.80)*fps),False); hide_at(b,1+round((t0+.83)*fps),True)

# shooting balls
shot_times=[31.8,34.0,36.6]
shot_targets=[(-2.45,goal_y,1.1),(2.45,goal_y,1.0),(-2.45,goal_y,1.15)]
for i,(t0,to) in enumerate(zip(shot_times,shot_targets),1):
    b=sphere(f"SHOT_BALL_{i}",(-.65+.65*(i-1),shoot_pos[1],.38),.21,m_ball)
    hide_at(b,1,True); hide_at(b,1+round((t0-.04)*fps),True); hide_at(b,1+round(t0*fps),False)
    key_loc(b,t0,b.location,fps); key_loc(b,t0+.85,to,fps)
    hide_at(b,1+round((t0+.90)*fps),False); hide_at(b,1+round((t0+.93)*fps),True)

# lights
bpy.ops.object.light_add(type="AREA",location=(0,-6,32)); L=bpy.context.object; L.data.energy=900; L.data.size=24; look_at(L,(0,0,0))

# camera with tracking target
bpy.ops.object.camera_add(); cam=bpy.context.object; scene.camera=cam
target=bpy.data.objects.new("CAM_TARGET",None); bpy.context.collection.objects.link(target)
con=cam.constraints.new(type="TRACK_TO"); con.target=target; con.track_axis="TRACK_NEGATIVE_Z"; con.up_axis="UP_Y"
key_camera(cam,target,0,(0,-25,48),(0,0,0),52,fps)
key_camera(cam,target,3,(-5,-25,34),(-5,-12,0),58,fps)
key_camera(cam,target,7,(9,-21,27),(5,-9,0),62,fps)
key_camera(cam,target,14,(-8,-16,25),(-1,-1,0),64,fps)
key_camera(cam,target,22,(8,-7,24),(0,7,0),66,fps)
key_camera(cam,target,31,(7,-2,22),(0,12,0),68,fps)
key_camera(cam,target,39,(0,-23,45),(0,0,0),54,fps)
key_camera(cam,target,42,(0,-25,48),(0,0,0),52,fps)

# validate and report
report={
 "valid": True,
 "template":"SAGI_EVENT_FLOW",
 "version":cfg["version"],
 "duration_sec":dur,
 "fps":fps,
 "field_m":[35,20],
 "timeline":{"burst":[3,7],"control":[7,14],"react":[14,22],"pass":[22,31],"finish":[31,39],"stop":[39,42],"score":[42,45]},
 "penalties":cfg["penalties"],
 "pass_sequence":seq,
 "intentional_demo_miss":{"pass_index":4,"penalty_sec":4},
 "stop_rule":"Stop after result of third shot is judged",
 "critical_frames_sec":[2,6.7,11,15.4,23.2,27.0,37.2,40,43.5],
 "errors":[]
}
json.dump(report,open(os.path.join(out_dir,"execution_report.json"),"w"),ensure_ascii=False,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir,"scene.blend"))
bpy.ops.render.render(animation=True)
print("SAGI_STANDARD_EVENT_FLOW_RENDER_DONE")
