#!/usr/bin/env python3
"""Narrate a chaptered EPUB into an .m4b audiobook with Chatterbox TTS.

More expressive than Kokoro: Chatterbox (Resemble AI, MIT) has an `exaggeration`
knob (monotone -> dramatic) and optional zero-shot voice cloning from a reference
clip. Fully offline at run time (model is pre-downloaded by `make audio-install`;
generation runs with HF_HUB_OFFLINE=1 set by the caller).

Pipeline: read EPUB spine docs (one per \\chapter) -> per chapter, split into
sentence-sized chunks -> Chatterbox generates each -> concat with short pauses ->
one wav per chapter -> ffmpeg assembles a chaptered .m4b (+ optional cover).
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def log(msg: str) -> None:
    print(f"[chatterbox] {msg}", flush=True)


def pick_device(pref: str) -> str:
    import torch

    if pref == "0":
        return "cpu"
    if pref == "1":
        return "cuda"
    # auto
    if torch.cuda.is_available():
        return "cuda"
    if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def read_chapters(epub_path: Path):
    """Return [(title, text), ...] in spine order, skipping empty docs."""
    from ebooklib import epub, ITEM_DOCUMENT
    from bs4 import BeautifulSoup

    book = epub.read_epub(str(epub_path))
    chapters = []
    for n, item in enumerate(book.get_items_of_type(ITEM_DOCUMENT), start=1):
        soup = BeautifulSoup(item.get_content(), "html.parser")
        heading = soup.find(["h1", "h2", "h3"])
        title = heading.get_text(strip=True) if heading else ""
        text = soup.get_text(separator=" ", strip=True)
        text = re.sub(r"\s+", " ", text).strip()
        if len(text) < 2:
            continue
        chapters.append((title or f"Chapter {len(chapters) + 1}", text))
    return chapters


def chunk_text(text: str, max_chars: int = 300):
    """Greedily pack sentences into chunks <= max_chars (Chatterbox is happiest
    with sentence-sized input; long blocks degrade)."""
    sentences = re.split(r"(?<=[.!?])\s+", text)
    chunks, cur = [], ""
    for s in sentences:
        s = s.strip()
        if not s:
            continue
        if len(s) > max_chars:  # hard-split a very long sentence on commas/spaces
            for piece in re.split(r"(?<=,)\s+", s):
                if len(cur) + len(piece) + 1 <= max_chars:
                    cur = f"{cur} {piece}".strip()
                else:
                    if cur:
                        chunks.append(cur)
                    cur = piece
            continue
        if len(cur) + len(s) + 1 <= max_chars:
            cur = f"{cur} {s}".strip()
        else:
            if cur:
                chunks.append(cur)
            cur = s
    if cur:
        chunks.append(cur)
    return chunks


def synth_chapter(model, text, out_wav, exaggeration, cfg, voice_sample):
    import torch
    import torchaudio

    sr = model.sr
    gap = torch.zeros(1, int(0.30 * sr))  # pause between chunks
    pieces = []
    kwargs = dict(exaggeration=exaggeration, cfg_weight=cfg)
    if voice_sample:
        kwargs["audio_prompt_path"] = voice_sample
    chunks = chunk_text(text)
    for i, chunk in enumerate(chunks, start=1):
        try:
            wav = model.generate(chunk, **kwargs)
        except Exception as e:  # don't lose a whole chapter to one bad chunk
            log(f"  chunk {i}/{len(chunks)} failed ({e}); skipping")
            continue
        if wav.dim() == 1:
            wav = wav.unsqueeze(0)
        pieces.append(wav.cpu())
        pieces.append(gap)
    if not pieces:
        return 0.0
    audio = torch.cat(pieces, dim=1)
    torchaudio.save(str(out_wav), audio, sr)
    return audio.shape[1] / sr  # seconds


def build_m4b(wavs, durations, titles, out_path, cover, bitrate, workdir):
    """Assemble per-chapter wavs into one chaptered .m4b via ffmpeg."""
    concat_list = workdir / "concat.txt"
    concat_list.write_text("".join(f"file '{w.name}'\n" for w in wavs))

    meta = workdir / "ffmeta.txt"
    lines = [";FFMETADATA1"]
    start_ms = 0
    for dur, title in zip(durations, titles):
        end_ms = start_ms + int(dur * 1000)
        safe = title.replace("=", " ").replace(";", " ").replace("\n", " ")
        lines += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={start_ms}",
                  f"END={end_ms}", f"title={safe}"]
        start_ms = end_ms
    meta.write_text("\n".join(lines) + "\n")

    cmd = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat_list),
           "-i", str(meta)]
    if cover:
        cmd += ["-i", str(cover)]
    cmd += ["-map", "0:a", "-map_metadata", "1"]
    if cover:
        cmd += ["-map", "2:v", "-disposition:v", "attached_pic"]
    cmd += ["-c:a", "aac", "-b:a", bitrate]
    if cover:
        cmd += ["-c:v", "copy"]
    cmd += ["-movflags", "+faststart", str(out_path)]
    log("assembling m4b with ffmpeg")
    subprocess.run(cmd, check=True, cwd=str(workdir))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epub", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--exaggeration", type=float, default=0.5)
    ap.add_argument("--cfg", type=float, default=0.5)
    ap.add_argument("--voice-sample", default="")
    ap.add_argument("--cover", default="")
    ap.add_argument("--cuda", default="auto", help="auto|1|0")
    ap.add_argument("--bitrate", default="96k")
    ap.add_argument("--build-dir", type=Path, default=None)
    args = ap.parse_args()

    from chatterbox.tts import ChatterboxTTS

    device = pick_device(args.cuda)
    log(f"loading Chatterbox on {device} "
        f"(exaggeration={args.exaggeration}, cfg={args.cfg})")
    model = ChatterboxTTS.from_pretrained(device=device)

    chapters = read_chapters(args.epub)
    if not chapters:
        log("no chapters found in epub")
        return 1
    log(f"{len(chapters)} chapters")

    workdir = args.build_dir or Path(tempfile.mkdtemp(prefix="chatterbox-"))
    workdir.mkdir(parents=True, exist_ok=True)
    voice_sample = args.voice_sample or None

    wavs, durations, titles = [], [], []
    for idx, (title, text) in enumerate(chapters, start=1):
        out_wav = workdir / f"ch{idx:03d}.wav"
        log(f"chapter {idx}/{len(chapters)}: {title!r} ({len(text)} chars)")
        dur = synth_chapter(model, text, out_wav, args.exaggeration, args.cfg,
                            voice_sample)
        if dur <= 0:
            log(f"  chapter {idx} produced no audio; skipping")
            continue
        wavs.append(out_wav)
        durations.append(dur)
        titles.append(title)

    if not wavs:
        log("no audio generated")
        return 1

    # Resolve cover to an absolute path: ffmpeg runs with cwd=workdir, so a path
    # relative to the manuscript dir (e.g. images/cover.png) must be absolutised.
    cover = str(Path(args.cover).resolve()) if (args.cover and Path(args.cover).is_file()) else ""
    build_m4b(wavs, durations, titles, args.out.resolve(), cover, args.bitrate,
              workdir)
    log(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
