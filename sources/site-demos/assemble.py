"""Turns the frames of a recording into an animated WebP.

A frame with "fade": n is reached through n blended frames instead of a cut.
"""
import json
import sys
from pathlib import Path

from PIL import Image

FADE_MS = 40


def build(name, out, quality=78):
    src = Path(__file__).resolve().parent / "work" / "frames" / name
    manifest = json.loads((src / "manifest.json").read_text())
    images, durations = [], []
    prev = None
    for entry in manifest:
        img = Image.open(src / entry["file"]).convert("RGB")
        if prev is not None and entry.get("fade"):
            n = entry["fade"]
            for k in range(1, n):
                images.append(Image.blend(prev, img, k / n))
                durations.append(FADE_MS)
        # identical consecutive frames are merged into one longer frame
        if prev is not None and images and img.tobytes() == images[-1].tobytes():
            durations[-1] += entry["ms"]
        else:
            images.append(img)
            durations.append(entry["ms"])
        prev = img
    images[0].save(out, save_all=True, append_images=images[1:], duration=durations, loop=0,
                   lossless=False, quality=quality, method=6, minimize_size=True, allow_mixed=True)
    total = sum(durations) / 1000
    print(f"{out}: {len(images)} frames, {total:.1f} s, {Path(out).stat().st_size // 1024} KiB")


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
