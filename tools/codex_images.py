#!/usr/bin/env python3
"""Makes pictures with the Codex CLI (`codex exec`, its image generation tool) from a list of jobs.

A job file is a JSON list of {"id", "refs": [image paths], "prompt", "scene": false}. Each job runs one
`codex exec` and the picture it generates (Codex keeps it under ~/.codex/generated_images) is copied to
OUT/<id>.png. `scene: true` asks for an opaque full scene instead of a cut-out on a transparent background.
Then `tools/import_generated.py OUT` cuts and scales them into godot/art.

What keeps the usage low (measured 2026-10-11): the model is `gpt-5.6-luna` with reasoning `low` (a ChatGPT account
cannot use `gpt-5.4-mini`), and the references are ONE small picture per job: three references cost ~137 000 tokens
for one icon, one strip of icons ~15 000. Put several reference icons side by side in one picture.

stdin is always closed: `codex exec` waits for piped input when it inherits an open stdin (a background
shell), which hung a run for 20 minutes on 2026-10-13. A cut-out that comes back fully opaque (a painted
checkerboard instead of transparency) is asked for again.

Codex' own sandboxed shell fails on this PC ("setup refresh had errors"), so the picture is read from the path
Codex prints, not saved by Codex.

When Codex cannot draw (its separate 24-hour image limit, or no picture came back) the job falls back to the
Antigravity CLI (`agy -p`, Gemini image generation; the owner's decision 2026-10-12). agy cannot give a real
transparent background (it paints a checkerboard), so a cut-out is asked on a flat magenta background and keyed
out here (`key_flat_background`). agy keeps its pictures under ~/.gemini/antigravity-cli/brain and other sessions
on this PC may be drawing there at the same time, so only the path agy prints for this job is used.
`--backend agy` skips Codex.

    python tools/codex_images.py jobs.json OUT_DIR [workers] [--backend codex|agy]
"""
import json
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Optional

from PIL import Image

MODEL = "gpt-5.6-luna"
EFFORT = "low"
CUTOUT = ("Use the image generation tool to draw ONE image. Warm miniature-diorama 3D illustration, soft lighting from the "
          "upper left, clean crisp edges with NO white or grey halo, true transparent background (real alpha, not a "
          "checkerboard), no text, no watermark. ")
SCENE = ("Use the image generation tool to draw ONE image. Warm miniature-diorama 3D illustration, soft lighting, a full "
         "opaque square scene with a painted background, no text, no watermark, no UI. ")


def fully_opaque(path: Path) -> bool:
    """True when a picture has no transparent pixel at all: a cut-out that came back with its background
    painted in (often a fake checkerboard) instead of real transparency."""
    picture = Image.open(path)
    return picture.mode not in ("RGBA", "LA", "PA") or picture.getchannel("A").getextrema()[0] == 255


def generated_path(stdout: str) -> Optional[Path]:
    for line in reversed(stdout.splitlines()):
        text = line.strip().strip("`").strip('"').strip("'")
        if text.endswith(".png") and "generated_images" in text and Path(text).exists():
            return Path(text)
    return None


AGY_MODEL = "gemini-3.8-flash-low"
AGY_CUTOUT = ("Use your image generation tool to draw ONE image. Warm miniature-diorama 3D illustration, soft lighting from "
              "the upper left, clean crisp edges, centered, on a perfectly flat solid pure magenta background (#FF00FF) filling "
              "the whole image, no shadow or gradient on the background, no checkerboard, no text, no watermark. ")
LIMIT_WORDS = ("usage limit", "usage_limit", "rate limit", "429", "한도")
# A picture path agy prints: plain or inside a file:// link, on Windows (C:\...\brain\x.jpg, C:/.../brain/x.jpg)
# or Linux/macOS (/home/.../brain/x.jpg).
AGY_PATH_RE = re.compile(r"(?<![A-Za-z/])((?:[A-Za-z]:[\\/]|/)[^\s()\[\]\"'`]*antigravity-cli[\\/]brain[\\/][^\s()\[\]\"'`]+\.(?:png|jpe?g|webp))")


def agy_paths(stdout: str) -> list[str]:
    """The picture paths in agy's output, file:// links turned into plain paths (file:///C:/x -> C:/x, file:///home/x -> /home/x)."""
    text = re.sub(r"file:///([A-Za-z]:)", lambda match: match.group(1), stdout).replace("file://", "")
    return [os.path.normpath(match) for match in AGY_PATH_RE.findall(text)]


BACKGROUND_REACH = 110.0  # colour distance from the key that still counts as background or its soft edge


def key_flat_background(image: Image.Image) -> Image.Image:
    """The picture with its flat background (the median colour of a border band, which agy never paints exactly
    #FF00FF) made transparent; the background colour is un-mixed from the soft edge."""
    import numpy as np
    rgb = np.asarray(image.convert("RGB")).astype(float)
    band = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3), rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
    key = np.median(band, axis=0)
    distance = np.sqrt(((rgb - key) ** 2).sum(-1))
    # Only the background reached from the border is removed: a pink or purple detail inside the subject,
    # however close to the key, stays opaque.
    from scipy import ndimage
    near, _ = ndimage.label(distance < BACKGROUND_REACH)
    edge_labels = np.unique(np.concatenate([near[0], near[-1], near[:, 0], near[:, -1]]))
    background = np.isin(near, edge_labels[edge_labels > 0])
    alpha = np.where(background, np.clip((distance - 40.0) / 70.0, 0.0, 1.0), 1.0)
    colour = np.clip((rgb - key * (1.0 - alpha[..., None])) / np.maximum(alpha, 1e-3)[..., None], 0, 255)
    return Image.fromarray(np.dstack([colour, alpha * 255.0]).astype("uint8"), "RGBA")


def run_agy(job: dict, dest: Path, work: Path) -> str:
    # agy runs in OUT/_work: references are made absolute against the caller's directory first.
    refs = [Path(ref).resolve() for ref in job.get("refs", [])]
    prompt = (SCENE if job.get("scene") else AGY_CUTOUT) + job["prompt"] + " Do not save or move any file; reply with the generated file path."
    for ref in refs:
        prompt += f" Reference image (same style and design): {ref}"
    cmd = ["agy", "-p", prompt, "--model", AGY_MODEL, "--print-timeout", "540s"]
    for ref in refs:
        cmd += ["--add-dir", str(ref.parent)]
    try:
        result = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=600, cwd=work, shell=(os.name == "nt"),
                                encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        return "FAILED agy timeout"
    paths = [p for p in agy_paths(result.stdout) if Path(p).exists()]
    if not paths:
        return "FAILED agy: " + result.stdout[-200:]
    picture = Image.open(paths[-1])
    (picture.convert("RGB") if job.get("scene") else key_flat_background(picture)).save(dest)
    return "ok (agy)"


def run(job: dict, out: Path, backend: str = "codex") -> tuple[str, str]:
    dest = out / f"{job['id']}.png"
    if dest.exists():
        return job["id"], "exists"
    work = out / "_work"
    work.mkdir(exist_ok=True)
    if backend == "agy":
        return job["id"], run_agy(job, dest, work)
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", str(work),
           "-m", MODEL, "-c", f'model_reasoning_effort="{EFFORT}"']
    for ref in job.get("refs", []):
        cmd += ["-i", str(ref)]
    cmd += ["--", (SCENE if job.get("scene") else CUTOUT) + job["prompt"] + " Reply with only the generated file path."]
    last = ""
    for _ in range(2):  # one retry
        try:
            result = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=600, shell=(os.name == "nt"),
                                    encoding="utf-8", errors="replace")
        except subprocess.TimeoutExpired:
            last = "timeout"
            continue
        picture = generated_path(result.stdout)
        if picture is not None and not job.get("scene") and fully_opaque(picture):
            last = "cut-out came back without a transparent background"
            continue  # ask again: a painted-in background cannot be cut out cleanly
        if picture is not None:
            shutil.copy(picture, dest)
            return job["id"], "ok"
        output = result.stdout + result.stderr  # codex exec prints its errors (e.g. the usage limit) on stderr
        last = output[-200:]
        if any(word in output.lower() for word in LIMIT_WORDS):
            break  # Codex' image limit: retrying will not help
    # Codex could not draw it: Antigravity instead.
    return job["id"], run_agy(job, dest, work) + " after codex failed"


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("jobs")
    parser.add_argument("out")
    parser.add_argument("workers", nargs="?", type=int, default=3)
    parser.add_argument("--backend", choices=["codex", "agy"], default="codex")
    options = parser.parse_args()
    jobs = json.loads(Path(options.jobs).read_text(encoding="utf-8"))
    out = Path(options.out)
    out.mkdir(parents=True, exist_ok=True)
    backend = options.backend
    with ThreadPoolExecutor(options.workers) as pool:
        for job_id, status in pool.map(lambda job: run(job, out, backend), jobs):
            print(job_id, status, flush=True)


if __name__ == "__main__":
    main()
