# Worldbuilding docs site (docs/). Managed with uv + MkDocs.
#
# The manuscript is LaTeX — build it from main/ (cd main && make pdf|mobile|word|epub).
# This root Makefile only handles the docs site.

.PHONY: docs docs-serve docs-build docs-install help

help:
	@echo "Worldbuilding docs site (uv + MkDocs):"
	@echo "  make docs-install   uv sync (create .venv, install mkdocs-material)"
	@echo "  make docs-serve     Live preview at http://localhost:8000"
	@echo "  make docs-build     Build static site into site/"
	@echo ""
	@echo "Manuscript (LaTeX) lives in main/ — run its build there:"
	@echo "  cd main && make pdf      Printer PDF"
	@echo "  cd main && make mobile   Mobile-friendly PDF"
	@echo "  cd main && make word     Standard manuscript .docx (Shunn)"
	@echo "  cd main && make epub     EPUB ebook"
	@echo "  cd main && make diff     Tracked-changes PDF vs. an earlier version"

docs-install:
	uv sync

docs-serve:
	uv run mkdocs serve

docs docs-build:
	uv run mkdocs build
