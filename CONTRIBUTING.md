# Working on Cohear

Two people, two lanes. This doc keeps us from stepping on each other.

## Who owns what

**Nick — systems**
`app.py` pipeline · transcription engines · session logging · fine-tuning · hardware · deployment · outreach

**[Friend] — language**
Stage 2 `clarify()` prompts and intent extraction · the phonological/IPA layer · phonological error analysis · output tone and register · reviewing outputs for accuracy

**Both** — user interviews, testimonials, deciding what ships.

## Ground rules

1. **Never commit participant data.** No audio, transcripts, consent forms, or `.env`. Check `git status` before every commit.
2. **Speaker codes, not names.** `S01`, `S02`. Applies to code, data, commits, and docs.
3. **Consent before recording.** Every time, no exceptions. Parental consent for minors.
4. **Branch for anything non-trivial**, then PR so the other person sees it:
   ```bash
   git checkout -b feature/phoneme-layer
   ```
5. **Readable over clever.** We have to explain this code to judges and SLPs.
6. **Don't break the other lane.** If a change touches `clarify()` or the pipeline signature, say so in the PR.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env      # add your own key — do NOT commit it
streamlit run app.py
```

Each of us uses our **own** OpenAI key. Never share a key in chat, in the repo, or in a screenshot.

## Definition of done

A change is done when it runs end to end, doesn't leak participant data, and either **moves the WER number** or **gets the tool in front of a real user**. If it does neither, it probably isn't the priority this week.
