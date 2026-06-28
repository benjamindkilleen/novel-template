#!/usr/bin/env bash
# Narrate an EPUB into a chaptered .m4b audiobook with Kokoro-82M via audiblez.
# Fully offline. Cross-platform: macOS (CPU) and Linux (CPU or CUDA GPU).
#
# Usage: audiobook.sh EPUB VOICE SPEED OUTPUT
# Run inside the conda env (so $CONDA_PREFIX points at it), e.g.:
#   mamba run -n novel-audio bash scripts/audiobook.sh audio-build/audio.epub af_heart 1.0 "Book.m4b"
set -euo pipefail

EPUB="${1:?usage: audiobook.sh EPUB VOICE SPEED OUTPUT}"
VOICE="${2:?missing VOICE}"
SPEED="${3:?missing SPEED}"
OUTPUT="${4:?missing OUTPUT}"

# --- Point Kokoro's G2P at espeak-ng (best-effort; harmless if already found) -
case "$(uname -s)" in
  Darwin)
    PREFIX="$(brew --prefix espeak-ng 2>/dev/null || true)"
    LIB="${PREFIX:+$PREFIX/lib/libespeak-ng.dylib}"
    DATA="${PREFIX:+$PREFIX/share/espeak-ng-data}"
    ;;
  *)
    LIB="$(ls "${CONDA_PREFIX:-/usr}"/lib/libespeak-ng.so* 2>/dev/null | head -1 || true)"
    DATA="${CONDA_PREFIX:-/usr}/share/espeak-ng-data"
    ;;
esac
[ -n "${LIB:-}" ] && [ -f "$LIB" ] && export PHONEMIZER_ESPEAK_LIBRARY="$LIB"
[ -n "${DATA:-}" ] && [ -d "$DATA" ] && export ESPEAK_DATA_PATH="$DATA"

# --- Privacy: narration makes ZERO network calls (hard-fail, never reach out) --
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PYTORCH_ENABLE_MPS_FALLBACK=1

# --- GPU: use --cuda on Linux when a GPU is present. CUDA=1 forces, CUDA=0 off,
#          CUDA=auto (default) enables it iff nvidia-smi exists. ----------------
CUDA_FLAG=""
case "${CUDA:-auto}" in
  1) CUDA_FLAG="--cuda" ;;
  0) CUDA_FLAG="" ;;
  *) command -v nvidia-smi >/dev/null 2>&1 && CUDA_FLAG="--cuda" ;;
esac

WORK="$(dirname "$EPUB")"
# audiblez writes per-chapter wavs + the .m4b into its CWD; keep them in WORK.
( cd "$WORK" && audiblez "$(basename "$EPUB")" -v "$VOICE" -s "$SPEED" $CUDA_FLAG )
mv "$WORK"/*.m4b "$OUTPUT"
echo "Wrote $OUTPUT"
