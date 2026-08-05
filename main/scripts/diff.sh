#!/usr/bin/env bash
#
# Build a "tracked changes" PDF of the manuscript: the current working tree
# (including uncommitted edits) marked up against an earlier committed version.
#
# Invoked by `make diff` from main/. Pick the baseline interactively, or pass it:
#   make diff REF=v1.0-draft
#   make diff REF=HEAD~5
#
# Tagged commits are listed first, since those are the versions you actually
# care about diffing against (drafts sent out, submissions, milestones).

set -euo pipefail

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_ROOT=$(git -C "$MAIN_DIR" rev-parse --show-toplevel)
# Path of main/ relative to the repo root, so we can find it inside an old tree.
MAIN_REL=${MAIN_DIR#"$REPO_ROOT"/}

INPUT=${INPUT:-main.tex}
TITLE=${TITLE:-TITLE}
AUTHOR=${AUTHOR:-Author}
# latexdiff markup style. UNDERLINE (default) strikes out cuts and underlines
# additions. CFONT is gentler on long prose deletions (color/size only, no
# \sout), CCHANGEBAR just bars the margin. See `latexdiff --help`.
DIFFTYPE=${DIFFTYPE:-UNDERLINE}
BUILD_DIR=${BUILD_DIR:-diff-build}

# How many recent commits to offer when picking interactively.
COMMIT_COUNT=${COMMIT_COUNT:-15}

die() { printf 'make diff: %s\n' "$*" >&2; exit 1; }

command -v latexdiff >/dev/null || die "latexdiff not found (it ships with TeX Live/MacTeX)."

# ---------------------------------------------------------------------------
# 1. Choose the baseline revision.
# ---------------------------------------------------------------------------

REF=${REF:-${1:-}}

if [ -z "$REF" ]; then
  [ -t 0 ] || die "no TTY to prompt on; pass a revision instead: make diff REF=<tag|sha>"

  # Tags newest-first, then recent commits that aren't already shown as a tag.
  refs=()
  labels=()

  tagged_shas=""
  while IFS=$'\t' read -r name date subject; do
    [ -n "$name" ] || continue
    refs+=("$name")
    labels+=("$(printf '\033[1m%-20s\033[0m %s  %s' "$name" "$date" "$subject")")
    tagged_shas="$tagged_shas $(git -C "$REPO_ROOT" rev-parse "$name^{commit}")"
  done < <(git -C "$REPO_ROOT" for-each-ref --sort=-creatordate \
             --format='%(refname:short)%09%(creatordate:short)%09%(contents:subject)' refs/tags)

  tag_count=${#refs[@]}

  while IFS=$'\t' read -r sha date subject; do
    [ -n "$sha" ] || continue
    case "$tagged_shas" in *"$(git -C "$REPO_ROOT" rev-parse "$sha")"*) continue ;; esac
    refs+=("$sha")
    labels+=("$(printf '%-20s %s  %s' "$sha" "$date" "$subject")")
  done < <(git -C "$REPO_ROOT" log -n "$COMMIT_COUNT" --format='%h%x09%ad%x09%s' --date=short)

  [ ${#refs[@]} -gt 0 ] || die "no commits to diff against."

  printf '\n\033[1mDiff the current manuscript against which version?\033[0m\n\n'
  if [ "$tag_count" -gt 0 ]; then
    printf '  Tagged versions:\n'
  else
    printf '  (no tags yet — tag a milestone with: git tag -a v1.0-draft -m "first draft")\n'
  fi
  for i in "${!refs[@]}"; do
    [ "$i" -eq "$tag_count" ] && printf '\n  Recent commits:\n'
    printf '  %3d) %s\n' "$((i + 1))" "${labels[$i]}"
  done

  printf '\nNumber, or any git revision [1]: '
  read -r choice </dev/tty || die "no selection."
  choice=${choice:-1}

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#refs[@]} ]; then
    REF=${refs[$((choice - 1))]}
  else
    # Anything else is treated as a revision the user typed directly.
    REF=$choice
  fi
fi

git -C "$REPO_ROOT" rev-parse --verify --quiet "$REF^{commit}" >/dev/null \
  || die "'$REF' is not a commit in this repository."

REF_SHORT=$(git -C "$REPO_ROOT" rev-parse --short "$REF^{commit}")
REF_DESC=$(git -C "$REPO_ROOT" log -1 --format='%ad  %s' --date=short "$REF")
printf '\nDiffing against \033[1m%s\033[0m (%s) — %s\n' "$REF" "$REF_SHORT" "$REF_DESC"

# ---------------------------------------------------------------------------
# 2. Export that version of the manuscript to a scratch tree.
# ---------------------------------------------------------------------------

OLD_TREE=$(mktemp -d "${TMPDIR:-/tmp}/novel-diff.XXXXXX")
trap 'rm -rf "$OLD_TREE"' EXIT

git -C "$REPO_ROOT" archive "$REF" | tar -x -C "$OLD_TREE"

OLD_MAIN="$OLD_TREE/$MAIN_REL/$INPUT"
[ -f "$OLD_MAIN" ] || die "$MAIN_REL/$INPUT does not exist at $REF."

# ---------------------------------------------------------------------------
# 3. Flatten each side into a single self-contained .tex, then diff.
#
#    latexdiff's own --flatten is not usable here: it splits the preamble off
#    at \begin{document} BEFORE expanding \input, and our \begin{document}
#    lives in content.tex rather than main.tex. latexdiff therefore concludes
#    the document has no preamble and silently omits the \DIFadd/\DIFdel
#    definitions, producing a .tex that fails to compile. Expanding first with
#    latexpand gives it a file whose \begin{document} is at the top level.
# ---------------------------------------------------------------------------

command -v latexpand >/dev/null || die "latexpand not found (it ships with TeX Live/MacTeX)."

mkdir -p "$MAIN_DIR/$BUILD_DIR"
BUILD="$MAIN_DIR/$BUILD_DIR"
DIFF_TEX="$BUILD/diff.tex"

# Run latexpand from inside each tree so relative \input paths resolve there.
flatten_into() { # $1 = directory holding $INPUT, $2 = destination file
  ( cd "$1" && latexpand "$INPUT" ) > "$2" 2>> "$BUILD/latexpand.log"
  grep -q '\\begin{document}' "$2" || die "flattened $2 has no \\begin{document}; see $BUILD_DIR/latexpand.log"
}

: > "$BUILD/latexpand.log"
flatten_into "$(dirname "$OLD_MAIN")" "$BUILD/old-flat.tex"
flatten_into "$MAIN_DIR" "$BUILD/new-flat.tex"

printf 'Running latexdiff (--type=%s)...\n' "$DIFFTYPE"
# latexdiff warns chattily about constructs it does not model; those are not
# failures, so only surface its output if it actually exits nonzero.
if ! latexdiff --type="$DIFFTYPE" \
      "$BUILD/old-flat.tex" "$BUILD/new-flat.tex" > "$DIFF_TEX" 2> "$BUILD/latexdiff.log"; then
  cat "$BUILD/latexdiff.log" >&2
  die "latexdiff failed."
fi

[ -s "$DIFF_TEX" ] || die "latexdiff produced an empty document; see $BUILD_DIR/latexdiff.log."

if grep -q 'DIFadd\|DIFdel' "$DIFF_TEX"; then
  # A diff missing the markup definitions compiles to "Undefined control
  # sequence" pages deep; catch it here where the cause is still obvious.
  grep -q 'providecommand{\\DIFadd}' "$DIFF_TEX" \
    || die "latexdiff emitted markup but no markup definitions; see $BUILD_DIR/latexdiff.log"
else
  printf '\nNo textual changes between %s and the working tree.\n' "$REF"
fi

# ---------------------------------------------------------------------------
# 4. Compile. TEXINPUTS points back at main/ so styles/ and images/ resolve.
# ---------------------------------------------------------------------------

OUT_NAME="${TITLE} by ${AUTHOR} (diff vs $(printf '%s' "$REF" | tr '/ ' '--')).pdf"

printf 'Compiling...\n'
cd "$MAIN_DIR/$BUILD_DIR"
export TEXINPUTS="$MAIN_DIR:$MAIN_DIR/styles:${TEXINPUTS:-}"
for pass in 1 2; do # Run twice so the TOC/refs settle.
  if ! pdflatex -interaction=nonstopmode -halt-on-error diff.tex > "pdflatex-$pass.log" 2>&1; then
    tail -40 "pdflatex-$pass.log" >&2
    die "pdflatex failed on the diff; full log at $BUILD_DIR/pdflatex-$pass.log"
  fi
done

mv diff.pdf "$MAIN_DIR/$OUT_NAME"
printf '\n\033[1mWrote:\033[0m %s\n' "$OUT_NAME"

if command -v open >/dev/null; then
  open "$MAIN_DIR/$OUT_NAME"
fi
