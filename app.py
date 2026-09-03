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
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import streamlit as st

from phonetics import (
    add_feature_distances,
    align_phones,
    build_profile,
    calculate_per,
    generate_reference_ipa,
    load_phone_recognizer,
    optional_dependency_status,
    recognize_phones,
    save_review,
    top_rule_descriptions,
    validate_speaker_code,
)

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


def clarify(client, raw_text, phonetic_rules=None, produced_ipa=None):
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
    phonetic_context = ""
    if phonetic_rules:
        phonetic_context = (
            "\n\nOptional supporting evidence from human-reviewed prior clips:\n- "
            + "\n- ".join(phonetic_rules)
            + "\nUse these patterns cautiously; they are not diagnoses or proof of the current word."
        )
    if produced_ipa:
        phonetic_context += (
            "\nCurrent automatic phone estimate: " + produced_ipa
            + "\nThis estimate may contain recognizer errors."
        )
    resp = client.chat.completions.create(
        model=CHAT_MODEL,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": raw_text + phonetic_context},
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


@st.cache_resource(show_spinner=False)
def cached_phone_recognizer():
    """Load the optional phone model once instead of once per click."""
    return load_phone_recognizer()


def recognize_uploaded_wav(audio_bytes):
    """Run Allosaurus on temporary audio without retaining the recording."""
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp:
            temp.write(audio_bytes)
            temp_path = temp.name
        return recognize_phones(temp_path, cached_phone_recognizer())
    finally:
        if temp_path:
            Path(temp_path).unlink(missing_ok=True)


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

    st.markdown("**Optional reviewed speaker profile**")
    clarify_speaker = st.text_input(
        "Anonymous speaker code", placeholder="S01", key="clarify_speaker"
    )
    use_profile = st.toggle(
        "Use reviewed phonetic patterns", value=False,
        help="Only patterns you manually validated at least three times are included.",
    )

    if st.button("Clarify", type="primary", disabled=audio_bytes is None):
        client = get_client()
        if client is None:
            st.error("Add your OpenAI API key in the sidebar first.")
        else:
            corr = load_corrections()
            with st.spinner("Hearing it right…"):
                raw = transcribe(client, audio_bytes, filename, vocab_hint)
            raw_fixed = apply_corrections(raw, corr)
            rules = []
            if use_profile and clarify_speaker.strip():
                try:
                    rules = top_rule_descriptions(clarify_speaker)
                except ValueError as error:
                    st.error(str(error))
            with st.spinner("Getting the point…"):
                clean, point = clarify(client, raw_fixed, phonetic_rules=rules)

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

            with st.expander("Phonetic context used"):
                if rules:
                    st.write(rules)
                else:
                    st.caption("No threshold-qualified reviewed rules were used.")

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
    st.subheader("Offline phonetic analysis")
    st.caption(
        "Compare a dictionary pronunciation with an automatic or manually reviewed phone estimate. "
        "Recognizer output is evidence to review—not a clinical transcription."
    )
    dependency_status = optional_dependency_status()
    missing = [
        label for key, label in {
            "reference_ipa": "Gruut reference IPA",
            "phone_recognizer": "Allosaurus phone recognition",
            "feature_distance": "PanPhon feature distance",
        }.items() if not dependency_status[key]
    ]
    if missing:
        st.info(
            "Optional features not currently available: " + ", ".join(missing)
            + ". Install with `pip install -r requirements-phonetics.txt`. "
            "Manual phone comparison still works."
        )

    c1, c2 = st.columns(2)
    speaker_code = c1.text_input("Speaker code", placeholder="S01", key="phon_speaker")
    clip_id = c2.text_input("Clip ID", placeholder="S01-C001")
    confirmed_text = st.text_input(
        "Speaker-confirmed text", placeholder="I need some water"
    )
    phon_audio = st.file_uploader(
        "Upload a WAV recording", type=["wav"], key="phonetic_audio"
    )
    source_options = ["Manual phone entry"]
    if dependency_status["phone_recognizer"]:
        source_options.insert(0, "Automatic Allosaurus estimate")
    phone_source = st.radio("Phone source", source_options, horizontal=True)
    manual_reference = st.text_input(
        "Manual reference phones (fallback; space-separated)",
        placeholder="w ɔ t ɚ",
        help="Used only when automatic reference IPA is unavailable or confirmed text is blank.",
    )
    manual_recognized = st.text_input(
        "Manual produced/recognized phones (space-separated)",
        placeholder="w ɔ ɚ",
        disabled=phone_source.startswith("Automatic"),
    )

    if st.button("Analyze phones", type="primary"):
        try:
            code = validate_speaker_code(speaker_code)
            if confirmed_text.strip() and dependency_status["reference_ipa"]:
                reference_display, expected = generate_reference_ipa(confirmed_text)
            else:
                expected = manual_reference.split()
                reference_display = " ".join(expected)
            if not expected:
                raise ValueError("Enter confirmed text or manual reference phones.")
            if phone_source.startswith("Automatic"):
                if phon_audio is None:
                    raise ValueError("Upload a WAV recording for automatic recognition.")
                with st.spinner("Estimating phones… the first model load may take a few minutes."):
                    recognized = recognize_uploaded_wav(phon_audio.getvalue())
            else:
                recognized = manual_recognized.split()
            if not recognized:
                raise ValueError("Enter manual recognized phones.")
            alignment = add_feature_distances(align_phones(expected, recognized))
            per = calculate_per(alignment)
            st.session_state["phonetic_analysis"] = {
                "speaker_code": code,
                "clip_id": clip_id.strip() or f"{code}-C001",
                "confirmed_text": confirmed_text.strip(),
                "reference_display": reference_display,
                "reference_phones": expected,
                "recognized_phones": recognized,
                "per": per,
                "alignment": alignment,
            }
        except Exception as error:
            st.error(str(error))

    analysis = st.session_state.get("phonetic_analysis")
    if analysis:
        st.metric("Phoneme Error Rate", f"{analysis['per']:.1%}")
        st.markdown("**Reference IPA**")
        st.code(analysis["reference_display"])
        st.markdown("**Automatic/manual phone estimate**")
        st.code(" ".join(analysis["recognized_phones"]))
        st.dataframe(analysis["alignment"], use_container_width=True)

        mismatches = [row for row in analysis["alignment"] if row["operation"] != "match"]
        if mismatches:
            st.markdown("### Human review")
            review_rows = []
            for row in mismatches:
                review_rows.append({
                    "expected": row["expected"], "recognized": row["recognized"],
                    "operation": row["operation"], "feature_distance": row.get("feature_distance"),
                    "review_decision": "unclear", "process": "not_classified",
                })
            edited_reviews = st.data_editor(
                review_rows,
                column_config={
                    "review_decision": st.column_config.SelectboxColumn(
                        "Review decision", options=["unclear", "speaker_pattern", "recognizer_error", "reference_issue"]
                    ),
                    "process": st.column_config.SelectboxColumn(
                        "Process", options=["not_classified", "final_consonant_deletion", "stopping", "fronting", "gliding", "cluster_reduction", "devoicing", "other"]
                    ),
                },
                disabled=["expected", "recognized", "operation", "feature_distance"],
                hide_index=True,
                use_container_width=True,
                key=f"review_{analysis['clip_id']}",
            )
            st.caption("Only rows marked speaker_pattern contribute to candidate rules.")
            if st.button("Save reviewed analysis"):
                analysis_record = {
                    "clip_id": analysis["clip_id"],
                    "saved_at": datetime.now(timezone.utc).isoformat(),
                    "per": analysis["per"],
                    "mismatches": (
                        edited_reviews.to_dict("records")
                        if hasattr(edited_reviews, "to_dict")
                        else edited_reviews
                    ),
                }
                save_review(analysis["speaker_code"], analysis_record)
                st.success("Saved locally under the anonymous speaker code. Audio was not saved.")
        else:
            st.success("No phone mismatches were found.")

    st.divider()
    st.markdown("### Speaker profile")
    profile_code = st.text_input("Profile speaker code", placeholder="S01")
    if st.button("Build reviewed profile"):
        try:
            profile = build_profile(profile_code)
            if profile:
                st.dataframe(profile, use_container_width=True)
                candidates = [row["description"] for row in profile if row["candidate_rule"]]
                if candidates:
                    st.success("Candidate rules: " + "; ".join(candidates))
                else:
                    st.info("No pattern has three reviewed examples yet.")
            else:
                st.info("No validated speaker-pattern mismatches have been saved for this code.")
        except ValueError as error:
            st.error(str(error))

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

            if m_up.name.lower().endswith(".wav") and optional_dependency_status()["phone_recognizer"]:
                try:
                    reference_display, reference_phones = generate_reference_ipa(reference)
                    recognized_phones = recognize_uploaded_wav(m_up.getvalue())
                    phone_alignment = align_phones(reference_phones, recognized_phones)
                    st.metric("Phone Error Rate", f"{calculate_per(phone_alignment):.1%}")
                    with st.expander("View phone comparison"):
                        st.code(reference_display)
                        st.dataframe(phone_alignment, use_container_width=True)
                except Exception as error:
                    st.warning(f"WER was measured, but PER could not be computed: {error}")
            else:
                st.caption("PER requires a WAV clip and the optional phonetics packages.")
