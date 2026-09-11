"""
Cohear — v0 MVP
Mission: understand people who are hard to understand.

Pipeline: audio -> Whisper (hear it right) -> LLM clarify + point (get the point) -> optional speech out.
Extras: two transcription engines (OpenAI API or free local Whisper), custom vocabulary bias,
per-user correction memory, and WER measurement for your headline number.

Run:  streamlit run app.py

Engines:
  - "OpenAI API"     — fastest to start. Needs OPENAI_API_KEY. ~$0.006/min.
  - "Local (free)"   — runs on your computer, $0, works offline, no key.
                       Install: pip install faster-whisper
"""

import os
import io
import json
from pathlib import Path

import streamlit as st

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

# ---------- Config (swap models here) ----------
TRANSCRIBE_MODEL = "whisper-1"      # Stage 1 when using the API
CHAT_MODEL = "gpt-4o-mini"          # Stage 2: get the point
TTS_MODEL = "tts-1"                 # optional: speak it back
TTS_VOICE = "alloy"
LOCAL_WHISPER_SIZE = "base"         # tiny | base | small | medium | large-v3
CORRECTIONS_PATH = Path("corrections.json")
# Your fine-tuned model: the "merged" folder produced by scripts/finetune_lora.py
# Our fine-tuned model. models/general/merged = trained on all 8 dysarthric
# speakers (34.6% WER on M04 vs 84.4% stock). Swap to models/m04b/merged for
# the single-speaker version.
FINETUNED_DIR = Path("models/general/merged")

st.set_page_config(page_title="Cohear — v0", page_icon="🗣️", layout="centered")


# ---------- OpenAI client ----------
def get_client():
    key = st.session_state.get("api_key") or os.environ.get("OPENAI_API_KEY")
    if not key or OpenAI is None:
        return None
    return OpenAI(api_key=key)


# ---------- Local Whisper (free, offline) ----------
@st.cache_resource(show_spinner="Loading local Whisper (first run downloads the model)…")
def get_local_model(size):
    from faster_whisper import WhisperModel
    # int8 keeps it fast and light on a laptop CPU.
    return WhisperModel(size, device="cpu", compute_type="int8")


def local_available():
    try:
        import faster_whisper  # noqa: F401
        return True
    except ImportError:
        return False


# ---------- Our fine-tuned model (trained on dysarthric speech) ----------
@st.cache_resource(show_spinner="Loading the fine-tuned model…")
def get_finetuned(model_dir):
    """Load the merged LoRA model produced by scripts/finetune_lora.py."""
    import torch
    from transformers import WhisperProcessor, WhisperForConditionalGeneration

    proc = WhisperProcessor.from_pretrained(model_dir, language="english", task="transcribe")
    model = WhisperForConditionalGeneration.from_pretrained(model_dir)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device).eval()
    forced = proc.get_decoder_prompt_ids(language="english", task="transcribe")
    return proc, model, device, forced


def finetuned_available():
    if not FINETUNED_DIR.exists():
        return False
    try:
        import torch, transformers  # noqa: F401
        return True
    except ImportError:
        return False


def transcribe_finetuned(audio_bytes, filename):
    import tempfile
    import torch
    import soundfile as sf

    proc, model, device, forced = get_finetuned(str(FINETUNED_DIR))
    suffix = Path(filename or "audio.wav").suffix or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name
    try:
        # soundfile handles wav/flac/ogg. m4a, mp3 and friends need librosa's
        # fallback decoders, so try the fast path first and degrade gracefully.
        try:
            audio, sr = sf.read(tmp_path, dtype="float32")
        except Exception:
            import librosa
            audio, sr = librosa.load(tmp_path, sr=16000, mono=True)
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        if sr != 16000:
            import librosa
            audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)

        # Whisper only sees 30 seconds at a time. Longer audio has to be split,
        # transcribed chunk by chunk, and stitched back together — otherwise
        # everything past 0:30 is silently dropped.
        CHUNK = 30 * 16000
        chunks = [audio[i:i + CHUNK] for i in range(0, len(audio), CHUNK)]
        chunks = [c for c in chunks if len(c) >= 1600]   # drop <0.1s tails

        pieces = []
        bar = st.progress(0.0, text=f"Transcribing {len(chunks)} chunk(s)…") if len(chunks) > 1 else None
        for i, chunk in enumerate(chunks):
            feats = proc.feature_extractor(
                chunk, sampling_rate=16000, return_tensors="pt"
            ).input_features.to(device)
            with torch.no_grad():
                ids = model.generate(feats, forced_decoder_ids=forced, max_new_tokens=400)
            text = proc.batch_decode(ids, skip_special_tokens=True)[0].strip()
            if text:
                pieces.append(text)
            if bar:
                bar.progress((i + 1) / len(chunks),
                             text=f"Transcribing… {i + 1}/{len(chunks)} chunks")
        if bar:
            bar.empty()
        return " ".join(pieces).strip()
    finally:
        os.unlink(tmp_path)


# ---------- Correction memory (simple per-user personalization) ----------
def load_corrections():
    if CORRECTIONS_PATH.exists():
        try:
            return json.loads(CORRECTIONS_PATH.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def save_corrections(corr):
    CORRECTIONS_PATH.write_text(json.dumps(corr, indent=2))


def apply_corrections(text, corr):
    for wrong, right in corr.items():
        if wrong:
            text = text.replace(wrong, right)
    return text


# ---------- Stage 1: hear it right ----------
def transcribe(audio_bytes, filename, vocab_hint, engine):
    """Route to whichever engine is selected. `vocab_hint` biases toward a speaker's words."""
    if engine == "Our fine-tuned model":
        return transcribe_finetuned(audio_bytes, filename)

    if engine == "Local (free)":
        import tempfile
        suffix = Path(filename or "audio.wav").suffix or ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name
        try:
            model = get_local_model(LOCAL_WHISPER_SIZE)
            segments, _ = model.transcribe(
                tmp_path,
                initial_prompt=vocab_hint or None,   # same trick as the API's `prompt`
                beam_size=5,
            )
            return " ".join(seg.text for seg in segments).strip()
        finally:
            os.unlink(tmp_path)

    client = get_client()
    if client is None:
        raise RuntimeError("No OpenAI API key. Add one in the sidebar, or switch the engine to Local (free).")
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename or "audio.wav"
    resp = client.audio.transcriptions.create(
        model=TRANSCRIBE_MODEL,
        file=audio_file,
        prompt=vocab_hint or None,
    )
    return resp.text


# ---------- Stage 2: get the point ----------
def clarify(client, raw_text):
    """Clean the transcript and extract the point. Returns (clean, point)."""
    system = (
        "You help listeners understand speech that is hard to understand: atypical speech, "
        "stutters, heavy accents, or indirect / rambling speech.\n"
        "Given a raw transcript, do two things:\n"
        "1) CLEAN: rewrite it as clear, fluent text that preserves the speaker's EXACT meaning "
        "and voice. Remove stutters, false starts, and filler. Never add information that isn't there.\n"
        "2) POINT: in one short sentence, state what the speaker is actually trying to say or ask.\n"
        "If the meaning is genuinely unclear, say so rather than guessing.\n"
        'Return strict JSON: {"clean": "...", "point": "..."}'
    )
    resp = client.chat.completions.create(
        model=CHAT_MODEL,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": raw_text},
        ],
        response_format={"type": "json_object"},
        temperature=0.2,
    )
    data = json.loads(resp.choices[0].message.content)
    return data.get("clean", ""), data.get("point", "")


def split_turns(client, raw_text):
    """
    Split a two-speaker transcript into labelled turns.

    NOTE: this infers speakers from CONTENT (who asks vs. who answers, and which
    parts are garbled), not from voice. True diarization uses the audio itself and
    is a separate technique. This is good enough for interviews and demos; say so
    honestly rather than implying the model recognised the voices.
    """
    system = (
        "You are given a raw, error-prone transcript of a conversation between two "
        "people. One is an interviewer or conversation partner whose speech transcribes "
        "cleanly. The other has a speech difference, so their portions are garbled, "
        "fragmented, or contain nonsense words.\n\n"
        "Split the transcript into turns. For each turn give:\n"
        '  "speaker": "Interviewer" or "Speaker"\n'
        '  "raw": the original text of that turn, unchanged\n'
        '  "clarified": a clear version preserving their exact meaning. If a turn is '
        "too garbled to interpret, write \"[unclear]\" rather than guessing.\n\n"
        "Never invent content. Never turn an unintelligible fragment into a confident "
        "sentence — say [unclear] instead.\n"
        'Return strict JSON: {"turns": [{"speaker": "...", "raw": "...", "clarified": "..."}]}'
    )
    resp = client.chat.completions.create(
        model=CHAT_MODEL,
        messages=[{"role": "system", "content": system},
                  {"role": "user", "content": raw_text}],
        response_format={"type": "json_object"},
        temperature=0.2,
    )
    data = json.loads(resp.choices[0].message.content)
    return data.get("turns", [])


def speak(client, text):
    """Optional: speak the clean text back in a clear voice. Returns mp3 bytes."""
    resp = client.audio.speech.create(model=TTS_MODEL, voice=TTS_VOICE, input=text)
    return resp.content


# ---------- Sidebar ----------
with st.sidebar:
    st.header("Setup")

    engine_options = ["OpenAI API", "Local (free)", "Our fine-tuned model"]
    engine = st.radio(
        "Transcription engine (Stage 1)",
        engine_options,
        help="Local runs Whisper on your computer: $0, offline, no key. "
             "The fine-tuned model is the one you trained on dysarthric speech.",
    )
    if engine == "Local (free)" and not local_available():
        st.error("Local engine needs faster-whisper:\n\n`pip install faster-whisper`")
    elif engine == "Local (free)":
        st.success(f"Local Whisper ‘{LOCAL_WHISPER_SIZE}’ — free & offline.")
        st.caption("Bigger = more accurate, slower. Change LOCAL_WHISPER_SIZE at the top of app.py.")
    elif engine == "Our fine-tuned model":
        if not FINETUNED_DIR.exists():
            st.error(
                f"No model at `{FINETUNED_DIR}`.\n\nTrain one first:\n\n"
                "`python scripts/finetune_lora.py --train data/torgo/train.jsonl "
                "--out models/torgo_general`"
            )
        elif not finetuned_available():
            st.error("Needs transformers:\n\n`pip install transformers torch soundfile`")
        else:
            st.success(f"Fine-tuned model loaded — `{FINETUNED_DIR}`")
            st.caption("Trained on dysarthric speech. Change FINETUNED_DIR at the top of app.py "
                       "to switch between a general model and a per-speaker one.")

    if not os.environ.get("OPENAI_API_KEY"):
        st.session_state["api_key"] = st.text_input(
            "OpenAI API key", type="password",
            help="Needed for the clarify step. Also needed for Stage 1 if engine = OpenAI API.",
        )
    st.caption("Stage 2 (clarify) always uses the API. Stage 1 is your choice.")

    st.divider()
    st.subheader("Custom vocabulary")
    vocab_hint = st.text_area(
        "Names, places, and words this speaker uses often",
        placeholder="e.g. Cupertino, CVS, my granddaughter Mei, dialysis",
        help="Biases the recognizer toward the right words. Works on both engines.",
    )
    st.divider()
    if engine == "OpenAI API":
        st.caption("Privacy: audio is sent to OpenAI. Get consent before recording real users.")
    else:
        st.caption("Privacy: audio stays on this computer for transcription. "
                   "Get consent before recording real users.")

st.title("🗣️ Cohear — v0")
st.caption("Hear it right → get the point. Hard-to-understand speech, made understandable.")

tab_clarify, tab_personalize, tab_measure = st.tabs(["Clarify", "Personalize", "Measure WER"])


# ---------- Tab: Clarify (the core loop) ----------
with tab_clarify:
    st.subheader("Record or upload speech")
    audio_bytes, filename = None, None

    rec = st.audio_input("Record")
    if rec is not None:
        audio_bytes, filename = rec.getvalue(), "recording.wav"

    up = st.file_uploader("…or upload a clip", type=["wav", "mp3", "m4a", "ogg", "webm", "flac"])
    if up is not None:
        audio_bytes, filename = up.getvalue(), up.name

    # Let people hear the original. In a demo this matters — the difficulty of
    # the audio is the whole argument, and it doesn't land from a transcript.
    if audio_bytes is not None:
        st.markdown("**Original audio**")
        st.audio(audio_bytes)
        st.caption(f"{filename} · {len(audio_bytes) / 1_000_000:.1f} MB")

    conversation_mode = st.checkbox(
        "This is a conversation between two people",
        help="Splits the transcript into turns and labels who said what. Inferred from "
             "content (who asks vs. who answers), not from voice.",
    )

    if st.button("Clarify", type="primary", disabled=audio_bytes is None):
        client = get_client()
        if client is None:
            st.error("The clarify step needs an OpenAI API key — add one in the sidebar.")
        else:
            corr = load_corrections()
            try:
                with st.spinner("Hearing it right…"):
                    raw = transcribe(audio_bytes, filename, vocab_hint, engine)
                raw_fixed = apply_corrections(raw, corr)
                turns = None
                if conversation_mode:
                    with st.spinner("Separating speakers…"):
                        turns = split_turns(client, raw_fixed)
                with st.spinner("Getting the point…"):
                    clean, point = clarify(client, raw_fixed)
            except Exception as e:
                st.error(f"Something went wrong: {e}")
            else:
                st.success(f"Done — Stage 1 via {engine}.")
                st.markdown("**The point**")
                st.info(point or "—")

                if turns:
                    st.markdown("### Conversation")
                    st.caption("Speakers inferred from content, not from voice.")
                    for t in turns:
                        who = t.get("speaker", "Speaker")
                        is_interviewer = who.lower().startswith("interview")
                        with st.chat_message("user" if is_interviewer else "assistant"):
                            st.markdown(f"**{who}**")
                            st.write(t.get("clarified") or "—")
                            if t.get("raw"):
                                st.caption(f"heard as: {t['raw']}")
                    st.divider()

                col_a, col_b = st.columns(2)
                with col_a:
                    st.markdown("**Raw (what Whisper heard)**")
                    st.write(raw or "—")
                with col_b:
                    st.markdown("**Clarified**")
                    st.write(clean or "—")

                # Replay the original next to the result, so a listener can
                # check the transcript against what they actually hear.
                with st.expander("▶︎ Listen to the original again"):
                    st.audio(audio_bytes)

                st.session_state["last_clean"] = clean

    if st.session_state.get("last_clean"):
        if st.button("🔊 Speak the clarified version"):
            client = get_client()
            if client:
                with st.spinner("Synthesizing…"):
                    mp3 = speak(client, st.session_state["last_clean"])
                st.audio(mp3, format="audio/mp3")


# ---------- Tab: Personalize (correction memory) ----------
with tab_personalize:
    st.subheader("Correction memory")
    st.caption("Teach the app this speaker's recurring mistakes. Applied automatically before clarifying.")
    corr = load_corrections()

    with st.form("add_correction"):
        c1, c2 = st.columns(2)
        wrong = c1.text_input("Heard as (wrong)")
        right = c2.text_input("Should be (right)")
        if st.form_submit_button("Add / update") and wrong:
            corr[wrong] = right
            save_corrections(corr)
            st.success(f"Saved: “{wrong}” → “{right}”")

    if corr:
        st.write(corr)
        if st.button("Clear all corrections"):
            save_corrections({})
            st.rerun()
    else:
        st.info("No corrections yet.")


# ---------- Tab: Measure WER (your headline number) ----------
with tab_measure:
    st.subheader("Word Error Rate: baseline vs. Cohear")
    st.caption("Upload a clip and paste what the speaker actually said. Lower WER = better. "
               "Log both numbers in your evidence tracker.")

    try:
        from jiwer import wer as _wer
        have_jiwer = True
    except ImportError:
        have_jiwer = False
        st.warning("Install jiwer to compute WER:  pip install jiwer")

    m_up = st.file_uploader("Clip to measure", type=["wav", "mp3", "m4a", "ogg", "webm", "flac"], key="measure")
    reference = st.text_area("Ground truth — exactly what the speaker meant to say")

    if st.button("Measure", disabled=not (have_jiwer and m_up and reference)):
        corr = load_corrections()
        try:
            with st.spinner("Transcribing twice (baseline, then ours)…"):
                raw = transcribe(m_up.getvalue(), m_up.name, "", engine)          # baseline: no vocab, no corrections
                improved = apply_corrections(
                    transcribe(m_up.getvalue(), m_up.name, vocab_hint, engine),   # ours: vocab + corrections
                    corr,
                )
        except Exception as e:
            st.error(f"Something went wrong: {e}")
        else:
            wer_base = _wer(reference, raw)
            wer_ours = _wer(reference, improved)
            c1, c2, c3 = st.columns(3)
            c1.metric("Baseline WER", f"{wer_base:.0%}")
            c2.metric("Cohear WER", f"{wer_ours:.0%}")
            delta = wer_base - wer_ours
            c3.metric("Improvement", f"{delta:.0%}", delta=f"{delta:.0%}")
            with st.expander("See both transcripts"):
                st.markdown("**Baseline**"); st.write(raw or "—")
                st.markdown("**Ours**"); st.write(improved or "—")
            st.caption("Copy these two numbers into the Clip Log tab of Cohear_Evidence_Tracker.xlsx.")