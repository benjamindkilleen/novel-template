INPUT=main.tex
TITLE=TITLE
DATE=$(shell date +%Y-%m-%d)
AUTHOR=Benjamin Killeen

# Audiobook (make audio), fully offline. Two engines via MODEL:
#   chatterbox (default) - expressive (EXAGGERATION knob), MIT, GPU-friendly
#   kokoro               - tiny/fast 82M via audiblez, flatter prosody
# Portable: macOS (CPU/MPS) and Linux (CPU or CUDA GPU). CUDA=auto|1|0.
#   make audio                                  # chatterbox, default expressiveness
#   make audio EXAGGERATION=0.7 CFG=0.3         # more dramatic, slower pacing
#   make audio VOICE_SAMPLE=narrator.wav        # clone a reference voice
#   make audio MODEL=kokoro VOICE=af_sky        # the old fast/flat engine
MODEL        ?= chatterbox
CUDA         ?= auto
AUDIO_ENV    ?= novel-$(MODEL)
CONDA        ?= mamba
AUDIO_BUILD  = audio-build
# Chatterbox knobs: exaggeration 0-1 (higher = more expressive), cfg 0-1
# (lower = slower/more deliberate pacing), temperature (lower = steadier prosody,
# fewer question-like rises). Chatterbox has NO preset voices — set VOICE_SAMPLE
# to a short clean WAV to pick the narrator's voice/gender (zero-shot clone).
EXAGGERATION ?= 0.5
CFG          ?= 0.3
TEMPERATURE  ?= 0.7
VOICE_SAMPLE ?= voices/narrator.wav
COVER        ?=
# `make audio-sample` narrates just a slice for fast voice/tuning A/B.
SAMPLE_CHAPTERS ?= 1
SAMPLE_SKIP     ?= 0
# Newer GPUs need a matching CUDA torch build (the default wheel lags). e.g. for
# an RTX 50-series (Blackwell, sm_120):
#   make audio-install TORCH_INDEX=https://download.pytorch.org/whl/cu128
TORCH_INDEX  ?=
# Kokoro knobs.
VOICE        ?= af_heart
SPEED        ?= 1.0
# conda needs --no-capture-output to stream progress live; mamba 2.x streams by
# default and rejects the flag (exec: --: invalid option).
RUN_STREAM   = $(if $(filter conda,$(CONDA)),--no-capture-output,)

pdf:
	pdflatex main.tex
	pdflatex main.tex # Run twice to ensure all references are updated
	mv main.pdf "${TITLE} by ${AUTHOR}.pdf"

mobile:
	pdflatex -jobname=mobile main.tex
	pdflatex -jobname=mobile main.tex # Run twice to ensure all references are updated
	mv mobile.pdf "${TITLE} by ${AUTHOR} (mobile) ${DATE}.pdf"

word:
	pandoc -o "${TITLE} by ${AUTHOR}.docx" word-main.tex \
		--reference-doc=styles/custom-reference-short.docx \
		--lua-filter=styles/manuscript.lua
	open "${TITLE} by ${AUTHOR}.docx"

rtf:
	latex2rtf simple-main.tex
	mv main.rtf "${TITLE}.rtf"

epub:
	pandoc -o "${TITLE} ${DATE}.epub" epub.tex --css=epub.css \
		--metadata author="${AUTHOR}" --metadata title="${TITLE} ${DATE}"

# One-time setup: create the novel-audio mamba env (python + ffmpeg), uv pip
# install the engine's deps (CUDA torch is pulled automatically on Linux), then
# pre-download the model so `make audio` is fully offline. Needs mamba/conda + uv.
# Installs for the current MODEL: `make audio-install` (chatterbox) or
# `make audio-install MODEL=kokoro`.
audio-install:
	$(CONDA) env create -n $(AUDIO_ENV) -f environment-audio.yml || $(CONDA) env update -n $(AUDIO_ENV) -f environment-audio.yml
ifeq ($(MODEL),kokoro)
	$(CONDA) run -n $(AUDIO_ENV) sh -c 'uv pip install --python "$$CONDA_PREFIX/bin/python" audiblez espeakng-loader'
	# Pre-fetch Kokoro model + default voice (tolerate API drift: first `make audio` can be online).
	-$(CONDA) run -n $(AUDIO_ENV) python -c "from kokoro import KPipeline; p=KPipeline(lang_code='a'); list(p('hello', voice='$(VOICE)'))"
else
	# setuptools<81: resemble-perth (watermarker) imports pkg_resources at load; uv envs
	# omit setuptools, and setuptools>=81 dropped pkg_resources, so pin below 81.
	$(CONDA) run -n $(AUDIO_ENV) sh -c 'uv pip install --python "$$CONDA_PREFIX/bin/python" chatterbox-tts ebooklib beautifulsoup4 resemble-perth "setuptools<81"'
	# --force-reinstall --no-deps overrides chatterbox's torch==2.6 pin (which otherwise
	# caps --upgrade) so a newer-GPU CUDA build actually replaces the bundled one. The
	# second (with-deps) pass backfills the matching nvidia-*-cu12 runtime libs the
	# new torch needs (e.g. libcufile.so.0) — without it CUDA import fails. Needed for
	# Blackwell (RTX 50-series, sm_120): use TORCH_INDEX=.../whl/cu128.
	$(if $(TORCH_INDEX),$(CONDA) run -n $(AUDIO_ENV) sh -c 'uv pip install --python "$$CONDA_PREFIX/bin/python" --force-reinstall --no-deps torch torchaudio --index-url $(TORCH_INDEX)')
	$(if $(TORCH_INDEX),$(CONDA) run -n $(AUDIO_ENV) sh -c 'uv pip install --python "$$CONDA_PREFIX/bin/python" torch torchaudio --index-url $(TORCH_INDEX)')
	# Pre-fetch the Chatterbox model so narration runs offline (load on CPU just to populate the cache).
	-$(CONDA) run -n $(AUDIO_ENV) python -c "from chatterbox.tts import ChatterboxTTS; ChatterboxTTS.from_pretrained(device='cpu')"
endif

# Build the audio EPUB: same source as `epub`, but the audio.lua filter strips
# \todo notes, summary blocks, and \scene "#" markers from the narration.
audio-epub:
	mkdir -p $(AUDIO_BUILD)
	pandoc -o $(AUDIO_BUILD)/audio.epub epub.tex --css=epub.css \
		--lua-filter=styles/audio.lua \
		--metadata author="${AUTHOR}" --metadata title="${TITLE}"

# Narrate the book into a chaptered .m4b audiobook, offline (engine = MODEL).
audio: audio-epub
ifeq ($(MODEL),kokoro)
	CUDA=$(CUDA) $(CONDA) run $(RUN_STREAM) -n $(AUDIO_ENV) \
		bash scripts/audiobook.sh $(AUDIO_BUILD)/audio.epub "$(VOICE)" "$(SPEED)" "${TITLE} by ${AUTHOR}.m4b"
else
	HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PYTORCH_ENABLE_MPS_FALLBACK=1 \
	$(CONDA) run $(RUN_STREAM) -n $(AUDIO_ENV) \
		python scripts/narrate_chatterbox.py --epub $(AUDIO_BUILD)/audio.epub \
		--out "${TITLE} by ${AUTHOR}.m4b" --cuda $(CUDA) --build-dir $(AUDIO_BUILD) \
		--exaggeration $(EXAGGERATION) --cfg $(CFG) --temperature $(TEMPERATURE) \
		$(if $(VOICE_SAMPLE),--voice-sample "$(VOICE_SAMPLE)",) \
		$(if $(COVER),--cover "$(COVER)",)
endif

# Quick Chatterbox tuning: narrate only SAMPLE_CHAPTERS chapter(s) (after skipping
# SAMPLE_SKIP) to "${TITLE} sample.m4b" so you can A/B voice/cfg/temperature fast.
#   make audio-sample VOICE_SAMPLE=narrator.wav CFG=0.25 TEMPERATURE=0.6
audio-sample: audio-epub
	HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PYTORCH_ENABLE_MPS_FALLBACK=1 \
	$(CONDA) run $(RUN_STREAM) -n $(AUDIO_ENV) \
		python scripts/narrate_chatterbox.py --epub $(AUDIO_BUILD)/audio.epub \
		--out "${TITLE} sample.m4b" --cuda $(CUDA) --build-dir $(AUDIO_BUILD) \
		--exaggeration $(EXAGGERATION) --cfg $(CFG) --temperature $(TEMPERATURE) \
		--skip $(SAMPLE_SKIP) --limit $(SAMPLE_CHAPTERS) \
		$(if $(VOICE_SAMPLE),--voice-sample "$(VOICE_SAMPLE)",) \
		$(if $(COVER),--cover "$(COVER)",)

clean:
	rm -rf _region_.* auto *.aux *.docx *.log *.out *.pdf *.toc *.rtf *.pages *.epub *.html *.synctex.gz *.fls *.fdb_latexmk *.m4b audio-build
