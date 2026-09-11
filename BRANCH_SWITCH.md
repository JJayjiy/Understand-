# Switching to `melodie-phonetics` — do this in order

Run these in Terminal. I can create files in your repo but not delete them, and git
needs to delete its own lock files — so a commit run from my side would leave the repo
stuck. These are safe to paste one block at a time.

---

## Step 0 — read this first

`git add -A` on your repo right now would stage **25,476 files, including the entire
15GB TORGO corpus**: the four `.tar.bz2` archives, every session folder, the EMA
articulatory data, the alignment files.

`.gitignore` covered `*.wav` and `models/`, but never `TORGO_datasets/`. I've fixed it.
**Do not run `git add -A` until you've confirmed the fix below.**

Two reasons this matters beyond tidiness: GitHub would reject it anyway (100MB per file,
5GB per repo), and pushing TORGO publicly would breach the terms Frank Rudzicz approved
your release under. His approval was explicitly conditioned on no corpus data being
included.

---

## Step 1 — confirm the .gitignore fix worked

```bash
cd ~/Desktop/Understand
git status --porcelain --untracked-files=all | wc -l
```

**You should see `35`.** If you see anything in the thousands, stop and tell me.

Then eyeball what would actually be committed:

```bash
git status --porcelain --untracked-files=all
```

Scripts, docs, outreach, results, the Space. No corpus.

---

## Step 2 — commit your work on main

All of it is currently uncommitted — the TORGO pipeline, the LoRA training script,
the eval results, the Space. Melodie has never seen any of it. That's almost certainly
why she built her branch off `v0` rather than off your current code.

```bash
cd ~/Desktop/Understand
rm -f .git/.writetest
git add -A
git commit -m "TORGO pipeline, LoRA training, eval results, HF Space, outreach docs"
git push origin main
```

---

## Step 3 — switch branches

```bash
git checkout melodie-phonetics
```

Your untracked local folders — `models/`, `TORGO_datasets/`, `.venv/` — stay put.
They're ignored, so they don't move between branches. Your trained adapter is safe.

To come back:

```bash
git checkout main
```

---

## Step 4 — run her code

```bash
pip install -r requirements-phonetics.txt
python -m unittest test_phonetics -v
```

I already ran those three tests against her `phonetics.py` in isolation and they pass.
The install is the slow part — Allosaurus pulls a phone model on first use.

```bash
streamlit run app.py
```

You'll get a **Phonetics** tab. Note that on this branch `app.py` is the *old* v0 app —
one engine, OpenAI API only. Your local Whisper toggle, the fine-tuned model option,
the 30-second chunking fix, and the conversation speaker-separation are all on `main`
and not here.

---

## What you'll have to deal with next: the merge

Her branch forked from `be545b2` (v0). Your `app.py` has moved a long way since then.
Both of you edited the same functions.

| Function | On `main` | On `melodie-phonetics` |
|---|---|---|
| `transcribe()` | routes between three engines | original single-engine signature |
| `clarify()` | added `split_turns` speaker separation | added `phonetic_rules`, `produced_ipa` params |
| tab layout | 3 tabs | 4 tabs (adds Phonetics) |

A straight `git merge` will conflict inside both functions. That's normal and fixable,
but don't attempt it five minutes before you need a working demo.

**The cheap way through it:** `phonetics.py` and `test_phonetics.py` are *new files* —
they don't conflict with anything. Only the `app.py` wiring does. So:

```bash
git checkout main
git checkout melodie-phonetics -- phonetics.py test_phonetics.py requirements-phonetics.txt
```

That pulls her module onto your branch cleanly. Then wire the Phonetics tab into your
current `app.py` by hand, using her version as the reference. Twenty minutes of careful
work instead of a three-way merge conflict inside a function you've both rewritten.

Do this *with her*, not for her — it's her code and she should stay the owner of it.

---

## One thing worth telling her

Her design gates the speaker profile on human review: a mismatch only counts if a
reviewer confirms it's a speaker pattern rather than an Allosaurus error, and a rule
needs three confirmed occurrences.

That's the most defensible decision in the codebase and it isn't in the spec I wrote —
she added it. The reasoning holds up: Allosaurus is itself trained mostly on typical
speech, so its errors on dysarthric audio correlate with exactly the thing you're
measuring. An unsupervised version would quietly turn the recognizer's limitations into
a confident-looking profile of a person's speech, and then act on it.

I've written it up as the centerpiece of the phonological section in the research brief,
and credited her by name. Tell her that.
