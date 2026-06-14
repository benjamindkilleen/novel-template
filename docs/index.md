# Story Bible

Welcome to the **story bible** — the canonical reference for everything in the
novel that *isn't* the prose itself: characters, places, factions, the rules
of the world, and the timeline of events.

Keeping this separate from the manuscript means you can check a detail without
scrolling through chapters, and your facts stay consistent as the book grows.

!!! tip "This site works like a wiki"
    These pages are plain Markdown in the `docs/` folder, one page per topic,
    organized into sections. The navigation builds itself from the folder
    structure, so **adding a page is just dropping a `.md` file into a folder** —
    nothing to register. Browse by the sidebar, by [Tags](tags.md), or with the
    search box. Preview it as a searchable website with:

    ```bash
    make docs-install   # one-time: installs MkDocs + plugins
    make docs-serve     # live preview at http://localhost:8000
    make docs-build     # static site into site/
    ```

## How to use this

- **[Synopsis & Outline](outline.md)** — the one-paragraph pitch, the longer
  synopsis, and a beat-by-beat outline.
- **[Characters](characters/index.md)** — one page per person: who they are, what
  they want, how they change.
- **[Locations](locations/index.md)** — places the story visits, with the sensory
  details that make them real.
- **[Factions & Organizations](factions/index.md)** — groups, their goals, and
  how they collide.
- **[World & Systems](world/index.md)** — the rules: magic, technology, politics,
  economy, religion — and their hard limits.
- **[Timeline](timeline.md)** — history before page one, plus the order of
  events in the story.

!!! note "Linking between pages"
    Use wikilinks — `[[maren]]`, `[[the-harbor-village]]` — and they resolve to
    the right page by filename, wherever it lives. No paths to keep straight.

## Working notes

- Date today: keep entries dated when they change so you can spot drift.
- Mark anything still undecided with `TODO` so search can find it.
- When the prose and the bible disagree, fix one on purpose — never both by
  accident.
