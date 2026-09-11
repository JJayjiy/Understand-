# The Phonological Layer (IPA) — Spec

**Owner: Friend (linguistics lead)** · Nick supports on implementation.

This is the layer that makes the linguistics real engineering instead of decoration — and it's the part no competitor is doing.

---

## Why this exists: the problem with word-level only

Today the pipeline is **audio → words → meaning**. When Whisper mis-hears, it emits the wrong *word* and destroys the acoustic evidence. Someone says "water" with a dropped final consonant; Whisper outputs "war." From "war" you cannot recover "water" — the sound information is gone.

Insert a phoneme layer and it becomes **audio → phones (IPA) → words → meaning**. Phones survive because the recognizer isn't forced to commit to a word. `/wɑʔɚ/` is recoverable. "war" isn't.

### The killer argument (use this in every pitch)

| Approach | Scales with | Generalizes? |
|---|---|---|
| Correction memory (today) | size of vocabulary — tens of thousands of entries | ❌ only fixes words you've already typed |
| Phoneme substitution rules | ~44 English phonemes | ✅ fixes words you've never seen |

If a speaker systematically deletes final /t/ and /d/, that's **one rule** that repairs thousands of words. Ten rules beat ten thousand corrections.

That asymmetry is the entire case for IPA, and it's the most technically credible thing in the project.

---

## It also unifies all three original use cases

| Case | What it really is |
|---|---|
| Dysarthria / special-needs speech | Documented phonological processes (final consonant deletion, stopping, fronting, devoicing) |
| Scottish / regional accents | Systematic phoneme mappings — this is literally what dialectology describes |
| Chinese-American / L2 speech | L1 transfer — systematic substitution from the first language |

All three are **systematic phoneme substitution**. One engine, three markets. That's a far stronger story than three separate features.

---

## Tools (all open source, all free)

| Tool | Job |
|---|---|
| **Allosaurus** (`xinjli/allosaurus`) | Pretrained universal phone recognizer, 2000+ languages, outputs IPA (~230-phone inventory). Audio → IPA. `pip install allosaurus` |
| **Wav2Vec2Phoneme** | Alternative multilingual phoneme recognition, zero-shot. Good cross-check |
| **panphon** (`dmort27/panphon`) | Maps IPA segments → articulatory feature vectors; computes **weighted feature edit distance**. This is how you measure *how close* two sounds are — /t/ and /d/ differ by one feature (voicing); /t/ and /m/ differ by many |
| **Epitran** | Grapheme → IPA (G2P). Sister library to panphon |
| **espeak-ng / phonemizer** | Alternative G2P |

> Precedent worth citing: there's published work on *Multilingual Dysarthric Speech Assessment Using Universal Phone Recognition* — this exact approach applied to dysarthria. You're on a documented path, not inventing from nothing.

---

## Architecture — where Layer 2 sits

```
audio
 ├─► Whisper (Stage 1)  ─────────────► candidate words
 └─► Allosaurus         ─────────────► produced IPA   /wɑʔɚ/
                                            │
              Epitran: candidate words → expected IPA  /wɔɹ/
                                            │
              panphon: feature-weighted distance(produced, expected)
                                            │
                   high distance ⇒ mis-hear detected
                                            │
                   accumulate per speaker ⇒ PHONOLOGICAL PROFILE
                                            │
   LLM (Stage 2) receives: produced IPA + speaker profile + candidates + context
                                            │
                                     "water"  ✅
```

**The prompt to Stage 2 becomes something like:**

> Speaker produced `/wɑʔɚ/`. Their profile shows final-consonant deletion and stopping. Whisper's candidates: *war, water, wader*. Context: kitchen. Which did they mean?

That's **phoneme-informed decoding with a speaker-specific phonological profile** — a real, nameable contribution you can put on a poster.

---

## The friend's workstream (this is a genuine research role)

1. **IPA-transcribe** a sample of collected clips by ear, alongside Allosaurus output.
2. **Categorize errors by phonological process** using standard clinical terms: final consonant deletion, stopping, fronting, gliding, cluster reduction, devoicing. *SLPs already use this vocabulary* — which means it speaks their language in the SJSU/RiteCare conversations.
3. **Build the per-speaker substitution rule set** from those patterns.
4. **Tune the distance metric** — choose which articulatory features matter most (panphon lets you weight them).
5. **Write the analysis** — this is the part that reads as research rather than a hackathon project.

---

## Metrics

- **PER (phoneme error rate)** — the phoneme-level analog of WER. Report alongside WER.
- **Profile coverage** — what % of a speaker's errors are explained by their rule set. Rising coverage over sessions = the system is learning them.
- **Ablation table** — WER with word-level only vs. with the phonological layer. This is the proof the layer earns its complexity.

---

## Honest caveats

- **Phone recognizers are also trained mostly on typical speech.** They degrade on dysarthric speech too — just more *gracefully* than word-level ASR. Don't oversell.
- **It adds latency and complexity.** Don't put it in the live earbud path for v1.
- **Recommended sequencing:** build it as an **offline "Phonetics" analysis tab** first. Prove it surfaces real, systematic patterns on your collected clips. Only then move it into the live pipeline.

---

## Claude Code task — paste this when you're ready to build it

> Add a **"Phonetics"** tab to `app.py` implementing a phoneme-level analysis layer.
>
> **Requirements:**
>
> 1. Add `allosaurus`, `panphon`, and `epitran` as optional dependencies. If they aren't installed, the tab shows install instructions instead of crashing — the rest of the app must keep working.
> 2. For a selected clip (or a new recording), produce and display:
>    - **Produced IPA** — Allosaurus output on the raw audio
>    - **Expected IPA** — Epitran G2P applied to the Whisper transcript (and, when available, to the ground-truth text)
>    - **Aligned comparison** — the two IPA strings aligned, with mismatches highlighted
>    - **Feature distance** per mismatch, via `panphon.distance.Distance()`
> 3. **Substitution table:** accumulate every (expected phone → produced phone) pair for the selected speaker across all their logged clips. Show it sorted by frequency, with counts. Persist to `data/phonological_profiles.json`, keyed by speaker code.
> 4. **Rule suggestions:** flag any substitution occurring 3+ times for that speaker as a candidate rule, and show it in plain language (e.g. "final /t/ → deleted, 7 occurrences").
> 5. **Feed the profile into Stage 2:** extend `clarify()` to optionally accept the speaker's produced IPA and their top substitution rules, and include them in the prompt so the LLM can disambiguate candidates. Keep this behind a toggle so I can A/B it.
> 6. Add **PER (phoneme error rate)** to the Measure tab, computed alongside WER whenever ground truth exists.
>
> **Constraints:**
> - Everything must degrade gracefully if the phonetics libraries are missing.
> - Speaker codes only, never names.
> - Comment the linguistics clearly — my teammate is the linguist and needs to read and modify this.
>
> **Acceptance criteria:** I can select a speaker with several logged clips and see a populated substitution table, at least one suggested rule, and a PER number next to my WER. Toggling the profile into Stage 2 visibly changes the prompt sent to the LLM.

---

**Sources:** [Allosaurus](https://github.com/xinjli/allosaurus) · [PanPhon](https://github.com/dmort27/panphon) · [PanPhon paper (COLING 2016)](https://aclanthology.org/C16-1328.pdf) · [Universal Phone Recognition with a Multilingual Allophone System](https://arxiv.org/pdf/2002.11800)
