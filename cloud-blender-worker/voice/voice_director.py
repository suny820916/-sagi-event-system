#!/usr/bin/env python3
"""SAGI VOICE DIRECTOR

Generate slot-locked Mandarin narration for a finished tactics video.
Principles:
- Never rewrite narration to fit.
- Every slot begins at its authored start time.
- No spoken audio may overflow its slot.
- Natural TTS rate adjustment comes before bounded ffmpeg time compression.
- Produce a machine-readable timing report and sentence-level SRT.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import re
import shutil
import subprocess
from pathlib import Path

import edge_tts


def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return p.stdout.strip()


def probe_duration(path: Path) -> float:
    out = run([
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(path),
    ])
    return float(out)


def pct(value: int) -> str:
    return f"{value:+d}%"


def pitch(value: int) -> str:
    return f"{value:+d}Hz"


def choose_rate(slot: dict, profile: dict) -> int:
    cps = float(slot.get("cjk_per_sec", 4.2))
    base = int(profile.get("rate_percent", 0))
    if cps >= 6.0:
        base += 16
    elif cps >= 5.5:
        base += 10
    elif cps >= 5.0:
        base += 6
    elif cps < 3.3:
        base -= 8
    elif cps < 3.8:
        base -= 4
    return max(int(profile.get("max_slow_percent", -14)),
               min(int(profile.get("max_rate_percent", 32)), base))


async def resolve_voice(profile: dict) -> str:
    preferred = profile.get("preferred_voice", "zh-CN-YunxiNeural")
    fallback_locale = profile.get("fallback_locale", "zh-CN")
    voices = await edge_tts.list_voices()
    names = {v.get("ShortName") for v in voices}
    if preferred in names:
        return preferred
    for v in voices:
        if v.get("Locale") == fallback_locale:
            return v["ShortName"]
    for v in voices:
        if str(v.get("Locale", "")).startswith("zh-"):
            return v["ShortName"]
    raise RuntimeError("No Chinese Edge TTS voice available")


async def synth(text: str, voice: str, rate_pct: int, volume_pct: int,
                pitch_hz: int, out: Path) -> None:
    communicate = edge_tts.Communicate(
        text=text,
        voice=voice,
        rate=pct(rate_pct),
        volume=pct(volume_pct),
        pitch=pitch(pitch_hz),
    )
    await communicate.save(str(out))
    if not out.exists() or out.stat().st_size == 0:
        raise RuntimeError(f"TTS created empty file: {out}")


def atempo_to_duration(src: Path, dst: Path, current: float, target: float) -> float:
    factor = current / target
    # Modern ffmpeg accepts a broad atempo range, but chaining keeps this
    # portable across runner versions.
    filters = []
    remaining = factor
    while remaining > 2.0:
        filters.append("atempo=2.0")
        remaining /= 2.0
    while remaining < 0.5:
        filters.append("atempo=0.5")
        remaining /= 0.5
    filters.append(f"atempo={remaining:.6f}")
    run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(src),
        "-filter:a", ",".join(filters),
        "-ar", "48000", "-ac", "2",
        str(dst),
    ])
    return factor


def to_wav(src: Path, dst: Path) -> None:
    run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(src),
        "-ar", "48000", "-ac", "2",
        str(dst),
    ])


def srt_time(sec: float) -> str:
    sec = max(0.0, sec)
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def split_clauses(text: str) -> list[str]:
    parts = [p.strip() for p in re.split(r"(?<=[。！？；])", text) if p.strip()]
    return parts or [text.strip()]


def text_weight(text: str) -> int:
    han = sum(1 for ch in text if "\u4e00" <= ch <= "\u9fff")
    return max(1, han)


def build_srt(slots_report: list[dict], out: Path) -> None:
    idx = 1
    lines: list[str] = []
    for row in slots_report:
        clauses = split_clauses(row["text"])
        spoken = max(0.2, float(row["final_duration_sec"]))
        total_w = sum(text_weight(c) for c in clauses)
        cursor = float(row["start"])
        slot_end = float(row["end"])
        for n, clause in enumerate(clauses):
            share = text_weight(clause) / total_w
            dur = spoken * share
            end = min(slot_end, cursor + dur)
            if n == len(clauses) - 1:
                end = min(slot_end, float(row["start"]) + spoken)
            lines.extend([
                str(idx),
                f"{srt_time(cursor)} --> {srt_time(end)}",
                clause,
                "",
            ])
            idx += 1
            cursor = end
    out.write_text("\n".join(lines), encoding="utf-8")


def mix_slots(wavs: list[tuple[Path, float]], total_sec: float, out: Path,
              target_lufs: float) -> None:
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for path, _ in wavs:
        cmd += ["-i", str(path)]

    chains = []
    labels = []
    for i, (_, start) in enumerate(wavs):
        delay = int(round(start * 1000))
        label = f"a{i}"
        chains.append(f"[{i}:a]adelay={delay}|{delay}[{label}]")
        labels.append(f"[{label}]")

    chains.append(
        "".join(labels)
        + f"amix=inputs={len(labels)}:duration=longest:normalize=0,"
          f"loudnorm=I={target_lufs}:TP=-1.5:LRA=7,"
          f"apad=pad_dur={total_sec},atrim=0:{total_sec}[mix]"
    )
    cmd += ["-filter_complex", ";".join(chains), "-map", "[mix]",
            "-ar", "48000", "-ac", "2", str(out)]
    run(cmd)


def mux(video: Path, audio: Path, out: Path, total_sec: float) -> None:
    run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(video), "-i", str(audio),
        "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-t", f"{total_sec:.3f}",
        "-movflags", "+faststart",
        str(out),
    ])


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--video", required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    config_path = Path(args.config)
    video = Path(args.video)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    seg_dir = out_dir / "segments"
    seg_dir.mkdir(exist_ok=True)

    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    profile = cfg["voice_profile"]
    total_sec = float(cfg["total_sec"])

    video_duration = probe_duration(video)
    if abs(video_duration - total_sec) > 0.25:
        raise RuntimeError(
            f"Video duration {video_duration:.3f}s does not match voice map {total_sec:.3f}s"
        )

    voice = await resolve_voice(profile)
    volume_pct = int(profile.get("volume_percent", 0))
    pitch_hz = int(profile.get("pitch_hz", 0))
    max_rate = int(profile.get("max_rate_percent", 32))
    min_rate = int(profile.get("max_slow_percent", -14))
    guard = float(profile.get("slot_tail_guard_sec", 0.12))
    occupancy = float(profile.get("target_occupancy", 0.90))

    report_slots = []
    mix_inputs: list[tuple[Path, float]] = []

    for slot in cfg["slots"]:
        sid = slot["id"]
        text = slot["voice_text"].strip()
        start = float(slot["start"])
        end = float(slot["end"])
        slot_dur = end - start
        available = max(0.25, slot_dur - guard)

        raw = seg_dir / f"{sid}_raw.mp3"
        fitted_mp3 = seg_dir / f"{sid}_fit.mp3"
        final_wav = seg_dir / f"{sid}.wav"

        rate_pct = choose_rate(slot, profile)
        await synth(text, voice, rate_pct, volume_pct, pitch_hz, raw)
        raw_dur = probe_duration(raw)

        # If the line is much shorter than its slot, slow the TTS slightly,
        # but never distort it merely to fill every frame.
        target_spoken = available * occupancy
        if raw_dur < target_spoken * 0.82 and rate_pct > min_rate:
            desired = int(round(rate_pct + (raw_dur / target_spoken - 1.0) * 100))
            slower = max(min_rate, min(rate_pct, desired))
            if slower != rate_pct:
                rate_pct = slower
                await synth(text, voice, rate_pct, volume_pct, pitch_hz, raw)
                raw_dur = probe_duration(raw)

        # If the line exceeds its slot, first ask TTS to speak faster.
        if raw_dur > available:
            bump = int(math.ceil((raw_dur / available - 1.0) * 108.0))
            faster = min(max_rate, max(rate_pct + 2, rate_pct + bump))
            if faster != rate_pct:
                rate_pct = faster
                await synth(text, voice, rate_pct, volume_pct, pitch_hz, raw)
                raw_dur = probe_duration(raw)

        time_factor = 1.0
        if raw_dur > available:
            time_factor = atempo_to_duration(raw, fitted_mp3, raw_dur, available)
            final_src = fitted_mp3
        else:
            final_src = raw

        to_wav(final_src, final_wav)
        final_dur = probe_duration(final_wav)
        overflow = max(0.0, final_dur - available)
        if overflow > 0.04:
            raise RuntimeError(f"Slot {sid} overflows by {overflow:.3f}s")

        tail = max(0.0, slot_dur - final_dur)
        mix_inputs.append((final_wav, start))
        report_slots.append({
            "id": sid,
            "start": start,
            "end": end,
            "slot_duration_sec": slot_dur,
            "text": text,
            "voice": voice,
            "tts_rate_percent": rate_pct,
            "raw_duration_sec": round(raw_dur, 3),
            "time_compression_factor": round(time_factor, 4),
            "final_duration_sec": round(final_dur, 3),
            "tail_silence_sec": round(tail, 3),
            "overflow_sec": round(overflow, 3),
            "status": "fit",
        })

    voice_wav = out_dir / "sagi_voice_101s.wav"
    srt = out_dir / "sagi_voice_101s.srt"
    final_mp4 = out_dir / "SAGI_TACTICS_CHRISTMAS_TREE_V1_VOICE.mp4"
    report = out_dir / "voice_director_report.json"

    mix_slots(mix_inputs, total_sec, voice_wav, float(profile.get("output_lufs", -16)))
    build_srt(report_slots, srt)
    mux(video, voice_wav, final_mp4, total_sec)

    final_video_duration = probe_duration(final_mp4)
    voice_duration = probe_duration(voice_wav)

    payload = {
        "project": cfg["project"],
        "voice_sync_version": cfg["version"],
        "voice": voice,
        "video_input_duration_sec": round(video_duration, 3),
        "voice_mix_duration_sec": round(voice_duration, 3),
        "final_video_duration_sec": round(final_video_duration, 3),
        "slots": report_slots,
        "all_slots_fit": all(x["overflow_sec"] <= 0.04 for x in report_slots),
        "text_lock_preserved": True,
    }
    report.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
