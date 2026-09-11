# Should the phonological layer ship?

**Question:** does the linguistics layer earn its place in the product, or should CoHear just be the TORGO-tuned weights?

**Short answer:** cut it from the live pipeline. Keep it as an offline analysis tool and as the research contribution. The evidence below is why.

---

## What I could and couldn't run

| Solution | Status | Result |
|---|---|---|
| **1. Control-speaker baseline** | ✅ ran | Noise floor 2.2% vs 7.9% signal; 3 of 15 flagged phones are false positives |
| **2. Two recognizers, same clip** | ❌ blocked | PyTorch CDN is proxy-blocked in my sandbox and the PyPI build segfaults. Needs your Mac. |
| **3. Waveform burst detection** | not attempted | Bigger job; only worth doing on patterns you intend to claim |
| **4. Frenchay cross-check** | ✅ ran as part of 1 | Severity gradient reproduced: M04 21.4%, M05 9.3%, controls 1.4–5.9% |
| **5. Active learning** | design only | Depends on 1 and 2 |

Solution 2 is the one still owed. But three findings below decide the question without it.

---

## Finding 1 — the speech is mostly phonetically correct

| Group | Clips with ≥1 phone error |
|---|---|
| Control | 7.1% |
| Dysarthric | **19.6%** |

**Four out of five dysarthric clips contain no phone-level error at all.**

Now hold that against the word-level result: stock Whisper got **84.4%** of words wrong on M04.

Those two numbers cannot both be explained by phoneme substitution. If M04 produces the correct phones in most clips and the recognizer still fails on the overwhelming majority of words, then **the thing breaking ASR is not phonemic**. It is below the phone level — timing, duration, prosody, voice quality, articulation precision, spectral shape. A rulebook of phone substitutions cannot reach any of that.

This is the central argument. The layer is modelling the wrong level of abstraction for the problem it was proposed to solve.

## Finding 2 — there isn't enough error to build rules from

Total dysarthric phone errors across 485 clips: **138.**

| Rank | Phone | Errors | Share | Cumulative |
|---|---|---|---|---|
| 1 | /s/ | 26 | 18.8% | 18.8% |
| 2 | /t/ | 13 | 9.4% | 28.3% |
| 3 | /ih/ | 12 | 8.7% | 37.0% |
| 4 | /r/ | 10 | 7.2% | 44.2% |
| 5 | /d/ | 9 | 6.5% | 50.7% |

At a three-confirmed-examples threshold you could construct maybe six to eight rules, and the largest is built on 26 observations. That is not a rule library. That is anecdote with a threshold on it.

## Finding 3 — the substitutions aren't consistent enough to be rules

The whole pitch was "one rule fixes thousands of words." That requires a phone to map reliably to *one* outcome.

| Phone | Errors | Most common outcome | Share | Distinct outcomes |
|---|---|---|---|---|
| /s/ | 26 | deleted | 62% | 7 |
| /t/ | 13 | → /d/ | 46% | 6 |
| /ih/ | 12 | → /iy/ | 25% | 6 |
| /r/ | 10 | deleted | 60% | 5 |
| /d/ | 9 | → /t/ | 67% | 2 |
| /sh/ | 7 | → /ch/ | 57% | 4 |

The best case, /d/ → /t/, holds 67% of the time on nine observations. /ih/ scatters across six outcomes with no majority at all.

A rule that fires correctly half the time isn't a repair. It's a hint — and a hint handed to a language model as evidence can just as easily drag a correct transcript to a wrong one.

## Finding 4 — the errors that remain aren't phonetic

Joining the phone analysis to the 59-clip CoHear evaluation gives 28 overlapping clips. Of the 13 the tuned model still gets wrong, **7 had phonetically clean speech.** Here they are:

| Said | CoHear heard |
|---|---|
| write | right |
| write | right |
| coupe | coop |
| dug | duck |
| of | ow |
| vat | dent |
| feed | she feeds |

**"write" → "right" is the whole argument in one line.** Those words are the same phonemes. /ɹaɪt/ and /ɹaɪt/. No phone-level representation can distinguish them, not in principle, not ever. Same for coupe/coop. Only context can.

So the errors surviving the LoRA divide roughly in half: some coincide with phone errors, where the layer might help probabilistically; the rest are homophones and context failures, which are a language-model problem, not a phonetics problem.

*(n=28 — treat the split as directional, not precise. The qualitative content is what matters, and it isn't ambiguous.)*

---

## The comparison

| | TORGO LoRA weights | Phonological layer |
|---|---|---|
| Measured effect | 84.4% → 34.6% WER | none measured |
| Works on | all error types, learned from audio | phone substitutions only (~46% of residual) |
| Rule reliability | n/a — learned end to end | 46–67% consistency |
| Setup cost for a new user | none | human review of every candidate pattern |
| Dependencies | transformers, peft | + allosaurus, gruut, panphon, torch |
| Latency | one forward pass | second recognizer + alignment + LLM prompt |
| Fails on homophones | yes | **also yes, and structurally cannot improve** |

The LoRA already learned the phonology — implicitly, from audio, without anyone naming a phoneme. The layer is a hand-built, human-reviewed, far more laborious version of a mapping the network extracted for free. That is why it doesn't earn a place in the live path.

---

## Recommendation

**Cut it from the v1 pipeline.** Ship the weights. That is the thing with a measured effect.

**Keep it in three places, because it is genuinely valuable in all three:**

**1. As an offline Phonetics tab.** This is what the original spec said to do first, and now there's data behind it rather than intuition. It stays useful and it stops adding latency and failure modes to the live path.

**2. As the clinical interface.** This is the strongest case and it's a different product for a different user. An SLP does not care about word error rate. "This speaker deletes /s/ 16% of the time, against 0.4% for matched controls" is a sentence in the vocabulary they already use, and no ASR metric can produce it. When you talk to RiteCare or CHC, that number is the one that lands — not 34.6%.

**3. As the research contribution.** The calibration result is the most methodologically interesting thing either of you has produced. "Three of fifteen apparent phonological patterns are measurement artifacts, and one points the wrong way" is a real warning to anyone building this kind of system, and nobody in your position has published it. It is what makes the brief worth a professor's time.

**Do not tell Melodie her work was wasted.** It wasn't, and that framing would be both unkind and inaccurate. Her review gate is what made this analysis conceivable — an unsupervised pipeline would have shipped the /ao/ false positive without anyone noticing. The finding *is* her contribution. It just turns out to be a finding about measurement rather than a feature in the app, and that is a normal, respectable outcome for a research direction.

---

## What would change this conclusion

Run these before treating the decision as final:

1. **Solution 2 on your Mac** — Allosaurus and Wav2Vec2Phoneme on the same clips. If the recognizers agree far more often than expected, phone evidence is more trustworthy than this analysis assumes.
2. **F-series and M01–M03.** This used two dysarthric speakers, the only ones with `phn_headMic` files. Different speakers may show more consistent substitutions.
3. **Connected speech.** Capped at 14 phones. Sentences may behave differently from isolated words, and coarticulation errors are where phone modelling should shine.
4. **`.PHN` provenance.** If those segmentations were forced-aligned with a typical-speech model rather than hand-labelled, phone errors are undercounted and Finding 1 weakens. Worth asking Rudzicz — you already have the thread open.

If 1 and 3 both come back strongly positive, revisit. Otherwise ship the weights.
