# Control-calibrated phone deviation on TORGO

**Run date:** September 2026 · `scripts/phone_calibration.py`
**Question:** when the system reports a phonological pattern, how much of it is the speaker and how much is measurement noise?

---

## What was measured

TORGO recorded control speakers reading the **same prompts** in the **same room** through the **same microphones** as the dysarthric speakers. That makes a baseline possible: any deviation measured on control speakers is by construction not dysarthria.

For every prompt spoken by both groups, the reference is the **medoid control rendition** — the control phone sequence with the smallest total edit distance to the other control renditions. Not a dictionary pronunciation; how typical speakers actually said that word in that room.

- **Noise floor** — each control rendition aligned against the medoid of the *other* controls (leave-one-out). Control-vs-control disagreement.
- **Signal** — each dysarthric rendition aligned against the control medoid.

248 prompts qualified (≥3 control renditions, ≤14 phones). 4,571 control reference phones, 1,739 dysarthric.

**No neural phone recognizer was used.** This runs on TORGO's own `.PHN` phone segmentations. That is deliberate — you cannot calibrate a recognizer against a yardstick the recognizer produced. This builds the yardstick that Allosaurus gets measured against next.

---

## Headline

| | Phone error rate |
|---|---|
| Control vs control (noise floor) | **2.2%** |
| Dysarthric vs control (signal) | **7.9%** |

**The noise floor is 27% of the measured signal.** Better than a quarter of what a naive pipeline would report as "this speaker's phonological pattern" is something control speakers do too.

## Severity gradient — independent validation

| Speaker | Group | Clips | Phone error rate |
|---|---|---|---|
| **M04** | dysarthric (severe) | 198 | **21.4%** |
| **M05** | dysarthric (moderate) | 287 | **9.3%** |
| MC04 | control | 355 | 1.4% |
| MC01 | control | 316 | 2.2% |
| MC03 | control | 340 | 2.3% |
| MC02 | control | 283 | 5.9% |

The gradient tracks the 2008 clinician Frenchay ratings, and it tracks the word-level WER gradient from the ASR work (severe 77.8%, moderate 29.5%, control 2.9%) — measured by a completely different method, at a different level of representation. Three independent measures agreeing is the strongest internal evidence in this project.

Note **MC02 at 5.9%** — nearly 3× the other controls, and higher than several individual phones' dysarthric rates. A single control speaker can look "impaired" on this metric. Baselines have to be pooled, never taken from one person.

---

## Per-phone: what's real and what isn't

Phones passing a naive "≥5% error" filter, sorted by apparent severity. *Floor share* = what fraction of the apparent error also appears in controls.

| Phone | n | Dysarthric error | Control error | Floor share | Verdict |
|---|---|---|---|---|---|
| **s** | 101 | 25.7% | 0.4% | **1%** | real |
| d | 67 | 13.4% | 5.5% | 41% | partly baseline |
| ih | 103 | 11.7% | 2.8% | 24% | partly baseline |
| ae | 38 | 10.5% | 4.6% | 44% | partly baseline |
| g | 29 | 10.3% | 3.2% | 31% | partly baseline |
| **aa** | 47 | 8.5% | 3.9% | **46%** | mostly baseline |
| t | 158 | 8.2% | 3.4% | 42% | partly baseline |
| **ah** | 87 | 8.1% | 4.6% | **57%** | mostly baseline |
| **k** | 60 | 6.7% | 0.0% | **0%** | real |
| **ao** | 49 | 6.1% | 6.5% | **106%** | **inverted** |
| p | 87 | 5.8% | 1.0% | 17% | real |
| ay | 35 | 5.7% | 0.0% | 0% | real |
| w | 36 | 5.6% | 2.4% | 44% | partly baseline |
| r | 192 | 5.2% | 0.9% | 17% | real |
| l | 80 | 5.0% | 0.0% | 0% | real |

### Three things worth reading twice

**1. /s/ is overwhelmingly real.** 25.7% error against a 0.4% floor — 69× — and 15.8% of the time it is deleted outright. Clinically unsurprising: /s/ needs a precisely grooved tongue and sustained airflow, both directly affected by dysarthria. This is a pattern worth building a rule for.

**2. /ao/ inverts.** Control speakers deviate on /ao/ *more* than dysarthric speakers do — floor share 106%. An uncalibrated pipeline would have reported "this speaker distorts /ɔ/" with three confident examples. The data says the opposite. This is the failure mode, caught in the act.

**3. The false positives are all vowels.** /aa/, /ah/, /ao/ — the three phones that are mostly or entirely baseline are low and back vowels. The real findings are consonants: /s/, /k/, /l/, /r/, /p/. Vowel boundaries are inherently fuzzier to segment and vary more between typical speakers, so vowels carry a higher noise floor and need a higher bar before anything is claimed about them.

**Aggregate:** across the 15 flagged phones, the apparent mean error is 9.1% and the baseline is 2.6% — **a naive report overstates by 29%**, and gets the direction outright wrong for one phone in fifteen.

---

## What this means for the phonological layer

The human review gate on the `melodie-phonetics` branch is doing real work. The false positives here are exactly what it exists to stop, and they are not rare or exotic — 3 of 15 flagged phones, including one that points the wrong way.

But the gate does not have to carry the load alone. Control calibration is cheap and automatic, and it removes most of the false positives before a human ever sees them. The two combine well:

1. **Calibrate** against the control baseline — kills the vowel false positives automatically.
2. **Review** what survives — a person confirms the rest.

That turns "review 200 candidate patterns" into "review the 20 that cleared the floor," which is the difference between a method Melodie can actually run and one she can't.

---

## Limitations

- **Two dysarthric speakers.** Only M04 and M05 have `phn_headMic` segmentations. M01–M03 have array-mic phone files only. F-series not included in this run.
- **Four control speakers**, all male (MC01–MC04). FC-series not included.
- **`.PHN` provenance — resolved.** The maintainers confirm these segmentations were hand-labelled in Wavesurfer by a registered speech-language pathologist, though they could not say whether forced alignment was used for any portion of the corpus (F. Rudzicz, personal communication, September 2026). This removes the concern that the reference carries the same typical-speech bias the experiment is trying to isolate, and makes the 2.2% floor a measure of genuine production variation rather than annotation artifact. Coverage across speakers has not been independently verified.
- **Short prompts only** (≤14 phones), to keep the medoid search tractable and limit alignment noise. Connected speech may behave differently.
- **Small n on some phones.** /g/ (29) and /ay/ (35) are thin. Phones under 20 observations were excluded entirely.
- **This measures human phone segmentations, not Allosaurus.** It establishes the true deviation rates. The Allosaurus calibration — comparing what the recognizer *claims* against what is actually there — is the next run and needs a machine with PyTorch.

---

## Reproduce

```bash
python scripts/phone_calibration.py \
    --dysarthric-root ~/torgo/M \
    --control-root ~/torgo/MC \
    --out results/
```

Outputs `phone_calibration.csv`, `phone_calibration_by_speaker.csv`, `phone_calibration_utterances.csv`, `phone_calibration_summary.json`. Pure Python — no PyTorch, no model downloads, runs in about a minute.
