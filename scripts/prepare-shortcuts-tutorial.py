#!/usr/bin/env python3
"""Shorten idle pauses in genuine simctl recordings without recreating any UI."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_root", type=Path)
    parser.add_argument("language", choices=["ja", "en", "ko"])
    parser.add_argument("--start", type=float, default=0)
    args = parser.parse_args()
    source = args.capture_root / "raw" / args.language / "recording-final.mov"
    target_dir = args.capture_root / "edited"
    target_dir.mkdir(exist_ok=True)
    target = target_dir / f"automation-tutorial-{args.language}.mp4"
    metadata = json.loads(run([
        "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(source)
    ]).stdout)
    duration = float(metadata["format"]["duration"]) - args.start
    # simctl stores variable-rate frames. Materialize held frames before trimming
    # so seeking into an idle interval does not skip the screen being displayed.
    prefix = f"fps=30:start_time=0,trim=start={args.start},setpts=PTS-STARTPTS,"
    scan = run([
        "ffmpeg", "-hide_banner", "-i", str(source),
        "-vf", prefix + "scale=360:-2,freezedetect=n=-70dB:d=1.0", "-an", "-f", "null", "-"
    ])
    (target_dir / f"freeze-detection-{args.language}.log").write_text(scan.stderr)
    drops = []
    freeze_start = None
    for kind, value in re.findall(r"freeze_(start|end): ([0-9.]+)", scan.stderr):
        value = float(value)
        if kind == "start":
            freeze_start = value
        elif freeze_start is not None:
            if value - freeze_start > 2.4:
                drops.append([freeze_start + 1.8, value - 0.2])
            freeze_start = None
    if freeze_start is not None and duration - freeze_start > 2.4:
        drops.append([freeze_start + 2.0, duration])
    # Keep normal-speed motion and readable pauses, removing only idle time.
    expression = "+".join(f"between(t\\,{a:.4f}\\,{b:.4f})" for a, b in drops)
    filters = prefix
    if expression:
        filters += f"select=not({expression}),"
    filters += "setpts=N/(30*TB),scale=720:1566:flags=lanczos,setsar=1,format=yuv420p"
    run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(source), "-vf", filters, "-an", "-c:v", "libx264", "-threads", "2",
        "-preset", "medium", "-crf", "20", "-movflags", "+faststart", str(target)
    ])
    result = json.loads(run([
        "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(target)
    ]).stdout)
    manifest = {
        "source": str(source),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_metadata": metadata,
        "start_seconds": args.start,
        "removed_idle_intervals_after_start": drops,
        "output": str(target),
        "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "output_metadata": result,
        "editing": "Original screen recording; idle pauses shortened; resized to 720x1566; no recreated UI or added audio.",
    }
    (target_dir / f"manifest-{args.language}.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )
    print(args.language, "seconds:", result["format"]["duration"], "bytes:", result["format"]["size"])


if __name__ == "__main__":
    main()
