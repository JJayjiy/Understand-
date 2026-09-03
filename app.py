"""
Understand — v0 MVP
Mission: understand people who are hard to understand.

Pipeline: audio -> Whisper (hear it right) -> LLM clarify + point (get the point) -> optional speech out.
Extras: custom vocabulary bias, per-user correction memory, and WER measurement for your headline number.

Run:  streamlit run app.py
Needs: an OpenAI API key (set OPENAI_API_KEY, or paste it in the sidebar).
"""

import os
import io
import json
from pathlib import Path

import streamlit as st

from phonetics import align_phones, calculate_per

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

# ---------- Config (swap models here) ----------
TRANSCRIBE_MODEL = "whisper-1"      # Stage 1: hear it right
CHAT_MODEL = "gpt-4o-mini"          # Stage 2: get the point
TTS_MODEL = "tts-1"                 # optional: speak it back
TTS_VOICE = "alloy"
CORRECTIONS_PATH = Path("corrections.json")

st.set_page_config(page_title="Understand — v0", page_icon="🗣️", layout="centered")


# ---------- OpenAI client ----------
def get_client():
    key = st.session_state.get("api_key") or os.environ.get("OPENAI_API_KEY")
    if not key or OpenAI is None:
        return None
    return OpenAI(api_key=key)


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


# ---------- Pipeline ----------
def transcribe(client, audio_bytes, filename, vocab_hint):
    """Stage 1: Whisper. `vocab_hint` biases toward a user's common words/names/places."""
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename or "audio.wav"
    resp = client.audio.transcriptions.create(
        model=TRANSCRIBE_MODEL,
        file=audio_file,
        prompt=vocab_hint or None,
    )
    return resp.text


def clarify(client, raw_text):
    """Stage 2: clean the transcript and extract the point. Returns (clean, point)."""
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


def speak(client, text):
    """Optional: speak the clean text back in a clear voice. Returns mp3 bytes."""
    resp = client.audio.speech.create(model=TTS_MODEL, voice=TTS_VOICE, input=text)
    return resp.content


# ---------- Sidebar ----------
with st.sidebar:
    st.header("Setup")
    if not os.environ.get("OPENAI_API_KEY"):
        st.session_state["api_key"] = st.text_input(
            "OpenAI API key", type="password",
            help="Or set the OPENAI_API_KEY environment variable.",
        )
    st.caption("Models are set at the top of app.py — swap freely.")
    st.divider()
    st.subheader("Custom vocabulary")
    vocab_hint = st.text_area(
        "Names, places, and words this speaker uses often",
        placeholder="e.g. Cupertino, CVS, my granddaughter Mei, dialysis",
        help="Biases the recognizer toward the right words. This is v1 personalization.",
    )
    st.divider()
    st.caption("Privacy: audio is sent to OpenAI for processing. Get consent before recording real users.")

st.title("🗣️ Understand — v0")
st.caption("Hear it right → get the point. Hard-to-understand speech, made understandable.")

tab_clarify, tab_personalize, tab_phonetics, tab_measure = st.tabs(
    ["Clarify", "Personalize", "Phonetics", "Measure WER"]
)

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

    if st.button("Clarify", type="primary", disabled=audio_bytes is None):
        client = get_client()
        if client is None:
            st.error("Add your OpenAI API key in the sidebar first.")
        else:
            corr = load_corrections()
            with st.spinner("Hearing it right…"):
                raw = transcribe(client, audio_bytes, filename, vocab_hint)
            raw_fixed = apply_corrections(raw, corr)
            with st.spinner("Getting the point…"):
                clean, point = clarify(client, raw_fixed)

            st.success("Done.")
            st.markdown("**The point**")
            st.info(point or "—")

            col_a, col_b = st.columns(2)
            with col_a:
                st.markdown("**Raw (what Whisper heard)**")
                st.write(raw or "—")
            with col_b:
                st.markdown("**Clarified**")
                st.write(clean or "—")

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

# ---------- Tab: Phonetics ----------
with tab_phonetics:
    st.subheader("Phonetic comparison")
    st.caption(
        "Compare reference phones with the phone recognizer's estimate."
    )

    speaker_code = st.text_input(
        "Speaker code",
        placeholder="S01",
    )

    expected_text = st.text_input(
        "Reference IPA — separate each phone with a space",
        placeholder="w ɔ t ɚ",
    )

    recognized_text = st.text_input(
        "Recognized phones — separate each phone with a space",
        placeholder="w ɔ ɚ",
    )

    if st.button("Compare phones"):
        expected = expected_text.split()
        recognized = recognized_text.split()

        if not speaker_code:
            st.error("Enter a speaker code such as S01.")
        elif not expected or not recognized:
            st.error("Enter both phone sequences.")
        else:
            alignment = align_phones(expected, recognized)
            per = calculate_per(alignment)

            st.metric("Phoneme Error Rate", f"{per:.1%}")
            st.dataframe(alignment, use_container_width=True)

# ---------- Tab: Measure WER (your headline number) ----------
with tab_measure:
    st.subheader("Word Error Rate: baseline vs. Understand")
    st.caption("Upload a clip and paste what the speaker actually said. Lower WER = better.")

    try:
        from jiwer import wer as _wer
        have_jiwer = True
    except ImportError:
        have_jiwer = False
        st.warning("Install jiwer to compute WER:  pip install jiwer")

    m_up = st.file_uploader("Clip to measure", type=["wav", "mp3", "m4a", "ogg", "webm", "flac"], key="measure")
    reference = st.text_area("Ground truth — exactly what the speaker meant to say")

    if st.button("Measure", disabled=not (have_jiwer and m_up and reference)):
        client = get_client()
        if client is None:
            st.error("Add your OpenAI API key in the sidebar first.")
        else:
            corr = load_corrections()
            with st.spinner("Transcribing…"):
                raw = transcribe(client, m_up.getvalue(), m_up.name, "")             # baseline: stock Whisper
                improved = apply_corrections(
                    transcribe(client, m_up.getvalue(), m_up.name, vocab_hint), corr  # ours: vocab + corrections
                )
            wer_base = _wer(reference, raw)
            wer_ours = _wer(reference, improved)
            c1, c2, c3 = st.columns(3)
            c1.metric("Baseline WER", f"{wer_base:.0%}")
            c2.metric("Understand WER", f"{wer_ours:.0%}")
            delta = wer_base - wer_ours
            c3.metric("Improvement", f"{delta:.0%}", delta=f"{delta:.0%}")
            st.caption("Log every clip in your evidence spreadsheet. This delta is your pitch headline.")
