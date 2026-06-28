INPUT=main.tex
TITLE=TITLE
DATE=$(shell date +%Y-%m-%d)
AUTHOR=Benjamin Killeen

# Audiobook (make audio). Kokoro-82M TTS via audiblez, fully offline.
# Portable: macOS (CPU) and Linux (CPU or CUDA GPU). CUDA=auto|1|0 (auto = use a
# GPU when nvidia-smi is present). Override voice/speed: make audio VOICE=af_sky SPEED=1.1
VOICE       ?= af_heart
SPEED       ?= 1.0
CUDA        ?= auto
AUDIO_ENV   ?= novel-audio
CONDA       ?= mamba
AUDIO_BUILD = audio-build
UNAME_S     := $(shell uname -s)

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

# One-time setup: create the novel-audio mamba env (python + ffmpeg), install
# espeak-ng per-OS, uv pip install audiblez (CUDA torch is pulled automatically
# on Linux), and pre-download the Kokoro voice so `make audio` is fully offline.
# Needs mamba/conda + uv (+ Homebrew on macOS).
audio-install:
	$(CONDA) env create -f environment-audio.yml || $(CONDA) env update -f environment-audio.yml
ifeq ($(UNAME_S),Darwin)
	command -v espeak-ng >/dev/null 2>&1 || brew install espeak-ng
else
	$(CONDA) install -y -n $(AUDIO_ENV) -c conda-forge espeak-ng
endif
	$(CONDA) run -n $(AUDIO_ENV) sh -c 'uv pip install --python "$$CONDA_PREFIX/bin/python" audiblez'
	# Pre-fetch Kokoro model + default voice (tolerate API drift: first `make audio` can be online).
	-$(CONDA) run -n $(AUDIO_ENV) python -c "from kokoro import KPipeline; p=KPipeline(lang_code='a'); list(p('hello', voice='$(VOICE)'))"

# Build the audio EPUB: same source as `epub`, but the audio.lua filter strips
# \todo notes, summary blocks, and \scene "#" markers from the narration.
audio-epub:
	mkdir -p $(AUDIO_BUILD)
	pandoc -o $(AUDIO_BUILD)/audio.epub epub.tex --css=epub.css \
		--lua-filter=styles/audio.lua \
		--metadata author="${AUTHOR}" --metadata title="${TITLE}"

# Narrate the book into a chaptered .m4b audiobook with Kokoro, offline.
audio: audio-epub
	CUDA=$(CUDA) $(CONDA) run --no-capture-output -n $(AUDIO_ENV) \
		bash scripts/audiobook.sh $(AUDIO_BUILD)/audio.epub "$(VOICE)" "$(SPEED)" "${TITLE} by ${AUTHOR}.m4b"

clean:
	rm -rf _region_.* auto *.aux *.docx *.log *.out *.pdf *.toc *.rtf *.pages *.epub *.html *.synctex.gz *.fls *.fdb_latexmk *.m4b audio-build
