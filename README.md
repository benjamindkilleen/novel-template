# LaTeX Novel Template

A template for writing a novel in LaTeX, plus a Markdown **worldbuilding
site** for keeping your story bible (characters, locations, timeline, …)
organized as the book grows.

- **Manuscript** — LaTeX in `main/`. Builds a print PDF, a mobile PDF, a
  standard (Shunn) manuscript `.docx` for submission, and an EPUB.
- **Worldbuilding docs** — Markdown in `docs/`, rendered as a searchable
  website with MkDocs (managed by [uv](https://docs.astral.sh/uv/)), like a
  Python project's documentation.

```
.
├── main/        # The novel — LaTeX source + Makefile
├── docs/        # Worldbuilding story bible — Markdown (MkDocs site)
├── mkdocs.yml   # Docs site config
├── pyproject.toml  # uv-managed deps for the docs site
└── Makefile     # Convenience targets for the docs site
```

## The manuscript (LaTeX)

Install LaTeX from [latex-project.org](https://www.latex-project.org/get/) or
your favorite distribution. Write your novel in `main/` — organize it into
parts/chapters under `main/parts/` (use `\input`, `\chapter{}` for chapters,
`\scene{}` for scene breaks). Edit `TITLE` and `AUTHOR` in `main/Makefile`,
and your title/contact block in `main/content.tex`.

From `main/`:

- `make` (or `make pdf`) — printer-paper PDF: `TITLE by AUTHOR.pdf`
- `make mobile` — mobile-friendly PDF: `TITLE by AUTHOR (mobile) DATE.pdf`
- `make word` — standard novel manuscript `.docx` (modern/Shunn format:
  double-spaced, 12pt, contact + auto word-count title page, chapter breaks).
  Uses `pandoc` — install from [pandoc.org](https://pandoc.org/installing.html).
- `make rtf` — RTF via `latex2rtf` (`brew install latex2rtf`).
- `make epub` — EPUB for e-readers.
- `make audio-install` — one-time setup for the audiobook: creates a `novel-audio`
  [mamba](https://mamba.readthedocs.io/)/conda env (Python + `ffmpeg`), installs
  `espeak-ng` (Homebrew on macOS, conda on Linux), `uv pip install audiblez`, then
  pre-downloads the Kokoro voice model. Needs mamba/conda + [uv](https://docs.astral.sh/uv/)
  (and Homebrew on macOS).
- `make audio` — narrate the book into a chaptered `.m4b` audiobook,
  `TITLE by AUTHOR.m4b`, using the open-source
  [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) TTS model (Apache-2.0)
  via [audiblez](https://github.com/santinic/audiblez). Override voice/speed:
  `make audio VOICE=af_sky SPEED=1.1`. Voices: `af_heart` (default, US female),
  `af_sky`, `am_michael` (US male), `bf_emma`/`bm_george` (British). The
  `\todo{}`, `summary`, and `\scene` markers are stripped from the narration.
- `make clean` — remove build artifacts.

**Runs anywhere — no GPU required.** Kokoro-82M is tiny and runs on CPU; on Apple
Silicon a full novel takes roughly an hour. On a Linux box with an NVIDIA GPU it
runs much faster: `make audio` auto-detects the GPU (`nvidia-smi`) and passes
`--cuda` — force it on/off with `make audio CUDA=1` / `CUDA=0`.

> **Privacy:** the audiobook is generated **fully offline** — your prose never
> leaves the machine. The only network access is a one-time *download* of the
> Kokoro model during `make audio-install`; `make audio` then runs with
> `HF_HUB_OFFLINE=1` and makes zero network calls (verify by turning off Wi-Fi
> after install and running `make audio`).

```bash
cd main
make pdf
make word
```

## The worldbuilding docs (Markdown + MkDocs)

The `docs/` folder is your **story bible** — synopsis & outline, characters,
locations, factions, world rules, and timeline. Preview it as a searchable
website (like a Python docsite).

Dependencies are managed with [uv](https://docs.astral.sh/uv/). Install uv
once (`curl -LsSf https://astral.sh/uv/install.sh | sh`), then:

```bash
uv sync                 # creates .venv/ and installs mkdocs-material
uv run mkdocs serve     # live preview at http://localhost:8000
uv run mkdocs build     # static site into site/
```

Or use the convenience targets from the repo root:

```bash
make docs-install   # uv sync
make docs-serve     # live preview
make docs-build     # static site -> site/
```

It works like a wiki: one Markdown page per topic, organized into folders
(`characters/`, `locations/`, `factions/`, `world/`). The sidebar navigation is
built automatically from the folder structure, so **adding a page is just
dropping a `.md` file into a folder** — no `mkdocs.yml` to edit. Cross-link pages
with wikilinks (`[[maren]]`), tag them in front matter (`tags: [character]`) to
browse by the Tags page, and use the search box for everything else. The preview
reloads live as you edit.
