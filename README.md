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
- `make clean` — remove build artifacts.

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
