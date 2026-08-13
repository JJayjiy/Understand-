# Understand — v0 MVP

Hard-to-understand speech, made understandable. Record or upload a clip → the app transcribes it
(**hear it right**), rewrites it clearly and states the point (**get the point**), and can speak it back.

This is the shared "brain." Later it powers both the earbuds+app and the fabricated hero device.

## What's in here
- `app.py` — the whole app (Streamlit, single file)
- `requirements.txt` — dependencies
- `.env.example` — where your API key goes
- `consent_form.md` — plain-language consent to use before recording real users

## Run it locally
```bash
cd understand-mvp
python -m venv .venv && source .venv/bin/activate      # optional
pip install -r requirements.txt
export OPENAI_API_KEY=sk-...                            # or paste it in the sidebar
streamlit run app.py
```
Opens at http://localhost:8501.

## The three tabs
- **Clarify** — the core loop. Record/upload → see the point, plus raw-vs-clarified side by side → speak it back.
- **Personalize** — teach it a speaker's recurring mis-hears (correction memory). This is your v1 personalization.
- **Measure WER** — upload a clip + paste what the speaker actually meant; get baseline vs. Understand word error rate. **This delta is your headline number.**

## Deploy a public URL (free)
- **Streamlit Community Cloud:** push this folder to GitHub → share.streamlit.io → point at `app.py` → add `OPENAI_API_KEY` in Secrets.
- **Hugging Face Spaces:** new Space (Streamlit SDK) → upload files → add the key as a Secret.

## Swapping models
All model names are constants at the top of `app.py` (`TRANSCRIBE_MODEL`, `CHAT_MODEL`, `TTS_MODEL`).
For v2, replace `whisper-1` with your fine-tuned model and keep everything else.

## Privacy (read before real users)
Audio is sent to OpenAI for processing. Get written/parental consent first (`consent_form.md`),
store as little as possible, and let users delete their data. Don't commit `corrections.json` or any real recordings.
