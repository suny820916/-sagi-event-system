#!/usr/bin/env python3
"""SAGI FINAL PACKAGING LAYER

Adds:
- persistent SAGI logo at the bottom safe area
- chapter main titles at the top
- tactical subtitle cues under each chapter title

This layer is intentionally post-render so tactical camera composition remains
independent from brand/text packaging.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def ass_time(sec: float) -> str:
    sec = max(0.0, float(sec))
    cs = int(round(sec * 100))
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def ass_escape(text: str) -> str:
    return (
        str(text)
        .replace("\\", r"\\")
        .replace("{", r"\{")
        .replace("}", r"\}")
        .replace("\n", r"\N")
    )


def write_ass(cfg: dict, out: Path) -> None:
    width, height = cfg.get("canvas", [540, 960])
    style = cfg["style"]
    main = style["main"]
    sub = style["subtitle"]

    lines = [
        "[Script Info]",
        "ScriptType: v4.00+",
        f"PlayResX: {int(width)}",
        f"PlayResY: {int(height)}",
        "ScaledBorderAndShadow: yes",
        "WrapStyle: 2",
        "",
        "[V4+ Styles]",
        "Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding",
        (
            f"Style: Main,{main['font']},{main['size']},{main['primary_ass']},"
            f"&H000000FF,{main['outline_ass']},&H00000000,-1,0,0,0,100,100,"
            f"{main.get('spacing',0)},0,1,{main['outline']},{main['shadow']},8,20,20,{main['margin_v']},1"
        ),
        (
            f"Style: Sub,{sub['font']},{sub['size']},{sub['primary_ass']},"
            f"&H000000FF,{sub['outline_ass']},&H00000000,0,0,0,0,100,100,"
            f"{sub.get('spacing',0)},0,1,{sub['outline']},{sub['shadow']},8,24,24,{sub['margin_v']},1"
        ),
        "",
        "[Events]",
        "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text",
    ]

    for row in cfg.get("main_titles", []):
        lines.append(
            f"Dialogue: 0,{ass_time(row['start'])},{ass_time(row['end'])},Main,,0,0,0,,{ass_escape(row['text'])}"
        )

    for row in cfg.get("subtitles", []):
        lines.append(
            f"Dialogue: 0,{ass_time(row['start'])},{ass_time(row['end'])},Sub,,0,0,0,,{ass_escape(row['text'])}"
        )

    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--video", required=True)
    ap.add_argument("--logo", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    cfg = json.loads(Path(args.config).read_text(encoding="utf-8"))
    video = Path(args.video)
    logo = Path(args.logo)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    ass_path = output.parent / "_sagi_final_titles.ass"
    write_ass(cfg, ass_path)

    brand = cfg["brand"]
    logo_width = int(brand.get("logo_width", 230))
    opacity = float(brand.get("opacity", 0.90))
    bottom_margin = int(brand.get("bottom_margin", 36))

    # libass handles the Chinese title layer. The logo remains a separate RGBA
    # overlay so it can be resized/repositioned without touching title timing.
    graph = (
        f"[0:v]ass={ass_path.as_posix()}[titled];"
        f"[1:v]scale={logo_width}:-1,format=rgba,colorchannelmixer=aa={opacity:.3f}[logo];"
        f"[titled][logo]overlay=(W-w)/2:H-h-{bottom_margin}:format=auto[vout]"
    )

    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(video),
        "-i", str(logo),
        "-filter_complex", graph,
        "-map", "[vout]",
        "-map", "0:a?",
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level", "3.1",
        "-pix_fmt", "yuv420p",
        "-preset", "veryfast",
        "-crf", "22",
        "-c:a", "copy",
        "-movflags", "+faststart",
        str(output),
    ]
    run(cmd)


if __name__ == "__main__":
    main()
