# Claude Code Build Brief — "Cohear"

**How to use this:** open your `understand-mvp` folder in Claude Code and paste **Task 1** below. When it's done and you've verified it, paste **Task 2**. Don't paste both at once — one task at a time produces better results and lets you catch problems early.

---

## Context to paste first (do this once, at the start of a session)

> I am building "Cohear" — a tool that makes hard-to-understand speech (atypical speech, stutters, heavy accents) understandable. It's a Streamlit app in this folder (`app.py`). The pipeline is: audio → Whisper transcription ("hear it right") → LLM cleanup + intent extraction ("get the point") → optional TTS playback. There are two transcription engines: the OpenAI API, and local `faster-whisper` (free/offline).
>
> I'm a high school student. Explain what you're doing as you go, keep the code readable and commented, and don't add dependencies unless they're necessary. Ask me before making architectural changes.

---

## Task 1 — Session logging & dataset capture

> Add automatic session logging to `app.py`. Right now every clip I process is discarded, which means I'm losing both my evidence and my future training data.
>
> **Requirements:**
>
> 1. Create a `data/` directory (gitignored) with `data/audio/` for clips and `data/sessions.csv` for the log.
> 2. Every time a clip is processed in the **Clarify** or **Measure WER** tab, save:
>    - the audio file to `data/audio/<speaker_code>_<timestamp>.wav`
>    - a row in `data/sessions.csv` with: `timestamp, speaker_code, audio_path, engine, duration_sec, raw_transcript, corrected_transcript, clean_text, point, ground_truth, baseline_wer, understand_wer, understood_yn, notes`
> 3. Add a **speaker code** input to the sidebar (default `S01`). Never collect real names — codes only.
> 4. Add a **ground truth** text box to the Clarify tab so I can type what the speaker actually meant right after recording. Leave it blank if I don't know. This field is what makes a clip usable for training later — prompt me to fill it.
> 5. Add a new **"Data"** tab that shows: total clips, clips per speaker, how many have ground truth, total minutes recorded. Include two download buttons — one for `sessions.csv`, one that exports a **training manifest** as JSONL with `{"audio_path": ..., "text": ...}` for every clip that has ground truth.
> 6. Add an **"Understood? Y/N"** toggle in the Clarify tab, saved to the log.
>
> **Constraints:**
> - Nothing in `data/` may be committed — update `.gitignore`.
> - If a write fails, show a warning but never lose the user's result on screen.
> - Keep it dependency-light: `csv`/`json` from the standard library is fine.
>
> **Acceptance criteria:** I record a clip, type the ground truth, and afterward `data/sessions.csv` has a complete row, the audio file exists on disk, and the Data tab counts it. The JSONL export opens and contains that clip.

---

## Task 2 — LoRA fine-tuning notebook

> Create `finetune_whisper_lora.ipynb` — a Colab-ready notebook that LoRA fine-tunes Whisper on atypical speech. It must run on a **free Colab T4 (16GB)**.
>
> **Requirements:**
>
> 1. **Setup cell** — install `transformers`, `datasets`, `peft`, `bitsandbytes`, `accelerate`, `jiwer`, `librosa`. Print the detected GPU.
> 2. **Config cell at the top** with all the knobs in one place: `MODEL_SIZE` (default `openai/whisper-small`), `LORA_R`, `LORA_ALPHA`, `LEARNING_RATE`, `NUM_EPOCHS`, `BATCH_SIZE`, `DATA_SOURCE`.
> 3. **Data loading — support two sources:**
>    - my own JSONL manifest (the export from Task 1), uploaded or mounted from Drive
>    - a public HuggingFace dataset by name
>    Normalize both into the same format. Resample all audio to 16kHz.
> 4. **Train/test split** — hold out 15–20%, stratified by speaker where possible. **The test set must never be trained on**; print a loud confirmation of the split sizes.
> 5. **Baseline evaluation** — run the *stock* model on the test set and print WER **before** any training. This is the number we're beating.
> 6. **LoRA setup** — PEFT with int8 quantization so it fits on a T4. Print the trainable-vs-total parameter count (should be well under 1%).
> 7. **Training loop** — HuggingFace `Seq2SeqTrainer`, with checkpointing so a Colab disconnect doesn't lose everything.
> 8. **Post-training evaluation** — WER on the same test set. Print a clear before/after comparison table plus the relative reduction.
> 9. **Optional per-speaker cell** — take the fine-tuned model and adapt it further on a single speaker's clips, then report that speaker's WER before and after. This is the most important cell in the notebook — comment it clearly.
> 10. **Export cell** — save the LoRA adapter, and show how to load it back for inference so I can plug it into `app.py`.
> 11. **Results cell** — print a small summary table (stock → general fine-tune → per-speaker) and save it as CSV so it drops straight into my tracker.
>
> **Constraints:**
> - Must run end-to-end on free Colab T4. If something won't fit, choose the smaller option and say so in a comment.
> - Include a tiny smoke-test mode (`SMOKE_TEST = True`) that runs on ~20 clips and 1 epoch so I can verify the whole pipeline in a few minutes before committing to a real run.
> - Add markdown cells explaining each step in plain language — I want to understand it, not just run it.
>
> **Acceptance criteria:** with `SMOKE_TEST = True` the notebook runs top to bottom without errors on a free T4 and prints a before/after WER table, even if the improvement is negligible on 20 clips.

---

## Task 3 (later — only after Task 2 works)

> Add a third engine option to `app.py` called **"Local + my fine-tune"** that loads my exported LoRA adapter on top of local Whisper. Keep the existing two engines working unchanged. Show in the sidebar which adapter is loaded.

---

## Ground rules to repeat if Claude Code drifts

- One task at a time; don't refactor beyond what was asked.
- Never commit audio, transcripts, `.env`, or API keys.
- Speaker codes, never names.
- Prefer readable code over clever code — I need to explain this to judges.
- If a library or approach won't work on free-tier compute, say so up front instead of building something I can't run.

---

## Verify before moving on

**After Task 1:** record a clip → check `data/sessions.csv` has the row → check the audio file exists → export the JSONL and open it.

**After Task 2:** run in smoke-test mode → confirm it prints a before/after WER table → confirm the train/test split sizes printed and the test set was held out.
