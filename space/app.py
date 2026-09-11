"""
CoHear — Hugging Face Space
Side-by-side: stock Whisper vs. our dysarthria-adapted model.

One model is loaded, not two. The LoRA adapter is toggled on and off around
the same weights, so "stock" and "CoHear" are genuinely the same base model
with and without adaptation — half the memory, half the load time, and a
strictly fairer comparison than running two separate checkpoints.
"""

import gradio as gr
import librosa
import soundfile as sf
import torch
from peft import PeftModel
from transformers import WhisperForConditionalGeneration, WhisperProcessor

# ZeroGPU Spaces require the inference function to be decorated with @spaces.GPU.
# On CPU Spaces that package is absent (or present but unusable), so fall back to a
# no-op decorator. Catching Exception, not just ImportError, is deliberate: `spaces`
# raises at decoration time on non-ZeroGPU hardware, and a demo that dies at import
# is worse than one that runs slowly.
try:
    import spaces

    def gpu(fn):
        return spaces.GPU(duration=120)(fn)
except Exception:
    def gpu(fn):
        return fn

BASE = "openai/whisper-small"
ADAPTER = "JJaysz/cohear-whisper-small-dysarthric"

# The model is loaded LAZILY, on the first transcription, not at import.
#
# Loading at import means the Space renders nothing until ~1GB of weights are
# downloaded and torch has warmed up. After the Space sleeps (48h idle on free
# hardware) the next visitor sits on a blank "Building" screen for minutes and
# leaves. Loading on first use lets the page appear in seconds; only the first
# transcription pays the cost, and it pays it behind a progress bar that says so.
_cache = {}


def get_model():
    """Load once, reuse forever. Returns (processor, model, forced_decoder_ids)."""
    if "model" not in _cache:
        print("loading model...")
        processor = WhisperProcessor.from_pretrained(BASE, language="english", task="transcribe")
        base_model = WhisperForConditionalGeneration.from_pretrained(BASE)
        base_model.config.forced_decoder_ids = None
        base_model.config.suppress_tokens = []

        # Pin the adapter load to CPU. On ZeroGPU there is no GPU at import time
        # and `spaces` patches torch so an unpinned safetensors load tries CUDA
        # and dies. Older peft releases lack the kwarg, hence the fallback.
        try:
            model = PeftModel.from_pretrained(base_model, ADAPTER, torch_device="cpu").eval()
        except TypeError:
            model = PeftModel.from_pretrained(base_model, ADAPTER).eval()

        _cache["processor"] = processor
        _cache["model"] = model
        _cache["forced"] = processor.get_decoder_prompt_ids(language="english", task="transcribe")
        print("ready.")
    return _cache["processor"], _cache["model"], _cache["forced"]


CHUNK = 30 * 16000          # Whisper's encoder sees exactly 30s; longer audio is
                            # silently truncated unless we split it ourselves.


def load_audio(path):
    try:
        audio, sr = sf.read(path, dtype="float32")
        if audio.ndim > 1:                  # stereo -> mono
            audio = audio.mean(axis=1)
        if sr != 16000:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)
    except Exception:                       # soundfile can't read m4a/aac; librosa can
        audio, _ = librosa.load(path, sr=16000, mono=True)
    return audio


def to_features(processor, chunk):
    return processor.feature_extractor(
        chunk, sampling_rate=16000, return_tensors="pt"
    ).input_features


def decode(processor, model, forced, feats):
    with torch.no_grad():
        ids = model.generate(feats, forced_decoder_ids=forced, max_new_tokens=200)
    return processor.batch_decode(ids, skip_special_tokens=True)[0].strip()


@gpu
def run(path, progress=gr.Progress()):
    if not path:
        return "", "", ""

    audio = load_audio(path)
    chunks = [audio[i:i + CHUNK] for i in range(0, len(audio), CHUNK)]
    chunks = [c for c in chunks if len(c) >= 1600]   # drop sub-0.1s tails
    if not chunks:
        return "", "", "That clip was too short — try a couple of seconds."

    cold = "model" not in _cache
    progress(0.0, desc="Waking up the model (first run only, ~30s)…" if cold
             else "Loading…")
    processor, model, forced = get_model()

    # On ZeroGPU the GPU only exists inside this decorated function.
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device)

    stock_parts, cohear_parts = [], []
    for i, c in enumerate(chunks):
        progress((i, len(chunks)), desc=f"Transcribing {i + 1} of {len(chunks)}…")
        feats = to_features(processor, c).to(device)
        with model.disable_adapter():       # adapter off = plain Whisper-small
            stock_parts.append(decode(processor, model, forced, feats))
        cohear_parts.append(decode(processor, model, forced, feats))  # adapter on

    stock = " ".join(p for p in stock_parts if p)
    cohear = " ".join(p for p in cohear_parts if p)

    note = ""
    if stock.strip().lower() == cohear.strip().lower():
        note = "Both models heard the same thing here — that happens on clearer speech."
    return stock, cohear, note


DESCRIPTION = """
Speech recognition is trained mostly on typical speech, so it works worst for the people
who need it most. On the TORGO corpus — same prompts, same microphones, same room —
stock Whisper makes **16× more errors** for speakers with dysarthria than for control speakers.

This is Whisper-small with a small adapter trained on 2.5 hours of dysarthric speech.
On the most severely affected speaker in the corpus, word error rate fell from
**84.4% to 34.6%**, and single-word accuracy rose from **8.1% to 67.6%**.

**Record or upload below.** You'll see what plain Whisper hears and what our model hears,
from the same audio.

*The first transcription after a quiet period takes about 30 seconds while the model loads.
Everything after that is quick.*
"""

NOTES = """
---
**This is a research artifact, not a clinically validated system.** It has not been evaluated
in any clinical trial, has not been reviewed by any regulatory body, and has not been tested
with any living participant. It assists a listener; it does not replace one, and it should
never be used where a misrecognition carries consequences the speaker cannot contest.

**Your audio is processed and discarded.** Nothing is stored or logged.

**Limitations:** trained on 8 adult speakers with dysarthria from cerebral palsy and ALS.
It does not transfer to autism-related speech differences, which involve different mechanisms.
34.6% word error is better, not solved.

Built by Jingjing Lei.

This model was fine-tuned using the TORGO Database of Acoustic and Articulatory Speech from
Speakers with Dysarthria. TORGO data are not included here and are subject to their original
terms of use; obtain it separately from the
[official source](http://www.cs.toronto.edu/~complingweb/data/TORGO/torgo.html).
Please cite Rudzicz, Namasivayam & Wolff (2012) when using TORGO. Non-commercial research use.
"""

with gr.Blocks(title="CoHear") as demo:
    gr.Markdown("# CoHear — understand people who are hard to understand")
    gr.Markdown(DESCRIPTION)

    audio_in = gr.Audio(sources=["microphone", "upload"], type="filepath",
                        label="Record or upload speech")
    go = gr.Button("Transcribe", variant="primary")

    with gr.Row():
        out_stock = gr.Textbox(label="Stock Whisper heard", lines=4)
        out_cohear = gr.Textbox(label="CoHear heard", lines=4)
    note = gr.Markdown()

    gr.Markdown(NOTES)

    go.click(run, inputs=audio_in, outputs=[out_stock, out_cohear, note])
    audio_in.stop_recording(run, inputs=audio_in, outputs=[out_stock, out_cohear, note])

demo.queue().launch()
