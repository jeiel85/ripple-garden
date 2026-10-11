#!/usr/bin/env python3
"""Makes pictures with the Codex CLI (`codex exec`, its image generation tool) from a list of jobs.

A job file is a JSON list of {"id", "refs": [image paths], "prompt", "scene": false}. Each job runs one
`codex exec` and the picture it generates (Codex keeps it under ~/.codex/generated_images) is copied to
OUT/<id>.png. `scene: true` asks for an opaque full scene instead of a cut-out on a transparent background.
Then `tools/import_generated.py OUT` cuts and scales them into godot/art.

What keeps the usage low (measured 2026-10-11): the model is `gpt-5.6-luna` with reasoning `low` (a ChatGPT account
cannot use `gpt-5.4-mini`), and the references are ONE small picture per job: three references cost ~137 000 tokens
for one icon, one strip of icons ~15 000. Put several reference icons side by side in one picture.

Codex' own sandboxed shell fails on this PC ("setup refresh had errors"), so the picture is read from the path
Codex prints, not saved by Codex.

    python tools/codex_images.py jobs.json OUT_DIR [workers]
"""
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

MODEL = "gpt-5.6-luna"
EFFORT = "low"
CUTOUT = ("Use the image generation tool to draw ONE image. Warm miniature-diorama 3D illustration, soft lighting from the "
          "upper left, clean crisp edges with NO white or grey halo, true transparent background (real alpha, not a "
          "checkerboard), no text, no watermark. ")
SCENE = ("Use the image generation tool to draw ONE image. Warm miniature-diorama 3D illustration, soft lighting, a full "
         "opaque square scene with a painted background, no text, no watermark, no UI. ")


def generated_path(stdout: str) -> Path | None:
    for line in reversed(stdout.splitlines()):
        text = line.strip().strip("`").strip('"').strip("'")
        if text.endswith(".png") and "generated_images" in text and Path(text).exists():
            return Path(text)
    return None


def run(job: dict, out: Path) -> tuple[str, str]:
    dest = out / f"{job['id']}.png"
    if dest.exists():
        return job["id"], "exists"
    work = out / "_work"
    work.mkdir(exist_ok=True)
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", str(work),
           "-m", MODEL, "-c", f'model_reasoning_effort="{EFFORT}"']
    for ref in job.get("refs", []):
        cmd += ["-i", str(ref)]
    cmd += ["--", (SCENE if job.get("scene") else CUTOUT) + job["prompt"] + " Reply with only the generated file path."]
    last = ""
    for _ in range(2):  # one retry
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600, shell=(os.name == "nt"),
                                    encoding="utf-8", errors="replace")
        except subprocess.TimeoutExpired:
            last = "timeout"
            continue
        picture = generated_path(result.stdout)
        if picture is not None:
            shutil.copy(picture, dest)
            return job["id"], "ok"
        last = result.stdout[-200:]
    return job["id"], "FAILED " + last


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    jobs = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(int(sys.argv[3]) if len(sys.argv) > 3 else 3) as pool:
        for job_id, status in pool.map(lambda job: run(job, out), jobs):
            print(job_id, status, flush=True)


if __name__ == "__main__":
    main()
