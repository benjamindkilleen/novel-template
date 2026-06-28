# Narrator voice reference

`narrator.wav` is a ~16s mono excerpt used as the Chatterbox voice-cloning
reference for `make audio` — it sets the narrator's voice/gender.

It is wired as the default `VOICE_SAMPLE` in the Makefile. Swap voices by
dropping in another clean ~10–20s clip and pointing `VOICE_SAMPLE` at it:

    make audio VOICE_SAMPLE=voices/your-clip.wav

## Source / license

Trimmed from the LibriVox recording *Sagebrush Cinderella*
(`fcc012_sagebrushcinderella_brand_kw_64kb.mp3`). LibriVox audio is in the
**public domain** — free to use, copy, and redistribute, no attribution
required. See https://librivox.org/pages/public-domain/
