# CoHear — adapting speech recognition to dysarthric speech

**Technical brief · September 2026**

Jingjing Lei (speech model, evaluation) and Melodie Lee (phonological layer)
Archbishop Mitty High School, Class of 2027

- **Live demo:** https://huggingface.co/spaces/JJaysz/cohear
- **Model weights:** https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric
- **Code:** https://github.com/JJayjiy/Understand-

---

## 1. The gap

Speech recognition is trained overwhelmingly on typical speech, so it fails worst for the people who would benefit from it most. This is easy to assert and rarely measured cleanly, so we measured it.

On the TORGO corpus, under identical conditions — same prompts, same microphones, same room, same recording sessions — the only variable is who is speaking:

| Speaker group | Sentence WER |
|---|---|
| Control (non-dysarthric), n=894 clips | **2.9%** |
| Dysarthric, n=468 clips | **48.0%** |

A ~16× difference, with the acoustic environment held constant.

The failure scales cleanly with clinical severity:

| Severity | Speakers | Clips | Sentence WER | Single-word accuracy |
|---|---|---|---|---|
| Control | FC01–03, MC01–04 | 894 | 2.9% | 71.3% |
| Mild | F03, F04, M03 | 207 | 12.7% | 62.2% |
| Moderate | M05 | 70 | 29.5% | 42.1% |
| Severe | F01, M01, M02, M04 | 191 | 77.8% | 12.9% |

Severity labels are Frenchay Dysarthria Assessment ratings made by clinicians and recorded with the corpus in 2008 — independent of this work and of the model. They predict machine error rate almost monotonically. Whatever the model is failing on, it is closely tracking what a trained human rated as harder to understand.

*Reporting note: roughly 75% of TORGO utterances are isolated words. Sentence WER and single-word exact-match accuracy are reported separately throughout, because a blended average of the two is not interpretable.*

---

## 2. Method

A LoRA adapter on `openai/whisper-small` (244M parameters).

- Adaptation on attention projections (`q_proj`, `v_proj`), r=32, α=64, dropout 0.05
- **3.5M trainable parameters of 245M — 1.44%**
- Training data: 2,651 utterances / 152 minutes from 8 dysarthric speakers (F01, F03, F04, M01–M05)
- 3 epochs, LR 1e-3, batch 8 × 2 accumulation
- **Hardware: a laptop CPU. 2.5 hours. $0.**

The last line is the part we think matters. Adapting a production speech model to atypical speech no longer requires a lab, a grant, or a GPU cluster. If that holds up, the bottleneck for accessible ASR stops being compute and becomes data access and clinical partnership.

---

## 3. Results

All conditions evaluated on the same 59 held-out utterances from speaker M04 (most impaired in the corpus). Same test set, same normalization, only the model differs. **No test utterance appeared in any training set.**

| Model | Trained on | Sentence WER | Single-word accuracy |
|---|---|---|---|
| `whisper-small`, stock | — | 84.4% | 8.1% (3/37) |
| + single-speaker LoRA | M04 only, 24 min | 50.8% | 54.1% (20/37) |
| **+ multi-speaker LoRA** | 8 speakers, 152 min | **34.6%** | **67.6% (25/37)** |

37 of the 59 held-out clips improved. None of the improved clips required more than 24 minutes of speech from the target speaker to reach the middle row.

### The finding we did not expect

**Pooled data from other dysarthric speakers outperformed the target speaker's own data.** Eight speakers' 152 minutes beat M04's own 24 minutes by a wide margin — 34.6% vs 50.8% WER.

We had assumed the opposite. Personalization is the standard framing in this space, and it implies an enrollment burden: record a hundred phrases before the tool works for you. If a shared model transfers, that burden may be avoidable — which likely matters more in deployment than the accuracy number does, given that the strongest documented predictor of assistive-technology abandonment is lack of user involvement in device selection, and enrollment friction is exactly the kind of thing that produces abandonment.

**Caveat we want to state plainly:** the multi-speaker training set *includes* M04. This is therefore not a clean transfer experiment, and we are not claiming leave-one-speaker-out generalization. That experiment is next and we have not run it yet.

---

## 4. What the errors actually look like

The substitutions are not random. From the held-out set, stock Whisper vs. the adapted model on the same audio:

| Spoken | Stock Whisper heard | CoHear heard |
|---|---|---|
| storm | *dumb* | storm |
| swarm | *its one* | swarm |
| knee | *nyeh* | knee |
| warm | *one* | warm |
| sip | *zip* | sip |
| feet | *deet* | feet |
| read | *what* | read |
| my sister made the flowered curtains | *my my my it took hugeapanmi the the flowering cotton din dinn* | my sister made the flowers cut thin |

Almost every one of these is a describable phonological process rather than noise: cluster reduction (*storm* → *dumb*), devoicing/voicing confusion (*sip* → *zip*), initial-consonant substitution (*feet* → *deet*), final-consonant deletion. A trained SLP would name these in the vocabulary they already use daily.

That observation is what motivates the next layer of the system.

---

## 5. A phonological layer, with a human in the loop

**Status: implemented and unit-tested; not yet evaluated at scale.** Built by Melodie Lee, our linguistics collaborator, on the `melodie-phonetics` branch.

The word-level pipeline is `audio → words → meaning`. When the recognizer mis-hears, it commits to a wrong *word* and destroys the acoustic evidence — from "dumb" you cannot recover "storm."

Inserting an intermediate representation gives `audio → phones (IPA) → words → meaning`. Phones survive because the system is not forced to commit to a lexical item prematurely.

The case for it is a scaling argument:

| Approach | Scales with | Generalizes to unseen words? |
|---|---|---|
| Per-word correction memory | vocabulary size — tens of thousands of entries | No |
| Phoneme substitution rules | ~44 English phonemes | Yes |

If a speaker systematically deletes final /t/ and /d/, that is *one rule* repairing thousands of words.

**What exists:** `gruut` produces expected IPA from confirmed text; **Allosaurus** produces estimated phones from the audio; the two sequences are aligned with a standard edit-distance alignment yielding matches, substitutions, deletions and insertions; **panphon** attaches a weighted articulatory feature distance to each substitution, so /t/→/d/ (one feature, voicing) is scored as nearer than /t/→/m/. PER is computed over reference phones. Confirmed rules are passed into the downstream disambiguation prompt behind an explicit toggle.

### The design decision we think is the interesting one

**Automatic phone output never becomes evidence on its own.** A mismatch only counts toward a speaker's profile if a human reviewer has explicitly marked it as a speaker pattern rather than a recognizer error, and a pattern only becomes a candidate rule after **three independently reviewed occurrences**.

This was a deliberate choice against the obvious design. Allosaurus is itself trained mostly on typical speech, so its errors on dysarthric audio are correlated with exactly the phenomena we are trying to measure. An unsupervised pipeline would happily accumulate the recognizer's own failures into a confident-looking "phonological profile" of a person — attributing a machine's limitation to a human being's speech, and then acting on it. The reviewer gate is what keeps the system from doing that.

The same conservatism runs through the rest: speaker identifiers are validated against an anonymous-code pattern and a name is rejected outright at the API boundary, and the rules handed to the language model are framed as cautious supporting evidence, explicitly not as diagnoses.

### We measured how badly this can go wrong

TORGO's control speakers read the same prompts in the same room through the same microphones, so a baseline is available: any phone-level deviation measured on control speakers is by construction not dysarthria. Using the corpus's own `.PHN` phone segmentations — no neural recognizer in the loop, deliberately — we aligned every rendition of 248 shared prompts against the medoid control rendition of the same prompt.

| | Phone error rate |
|---|---|
| Control vs control (noise floor) | 2.2% |
| Dysarthric vs control (signal) | 7.9% |

**The noise floor is 27% of the measured signal.** And the per-speaker numbers reproduce the severity gradient independently: M04 (severe) 21.4%, M05 (moderate) 9.3%, controls 1.4–5.9% — the same ordering the clinician ratings and the word-level WER both give, arrived at by a different method at a different level of representation.

Of 15 phones that a naive "≥5% error" filter would flag as speaker patterns, **three are mostly baseline** — /aa/, /ah/, /ao/ — and **/ao/ inverts entirely**: control speakers deviate on it *more* than dysarthric speakers do. An uncalibrated pipeline would have reported "this speaker distorts /ɔ/," with confident examples, in the exact opposite direction of the truth.

The signal that survives is clean and clinically sensible. /s/ shows 25.7% error against a 0.4% floor — 69× — and is deleted outright 15.8% of the time, which is what one would predict for a phone requiring precise tongue grooving and sustained airflow. Notably, every false positive was a vowel and every robust finding a consonant.

**What this changes:** control calibration removes most false positives automatically, before a human sees them. Combined with the review gate, it turns "review 200 candidates" into "review the 20 that cleared the floor" — the difference between a method that can be run at scale and one that can't.

**What is still not done:** this measures human phone segmentations, not Allosaurus. It establishes the true deviation rates — the yardstick. Measuring what the *recognizer* claims against that yardstick is the next run. And there is still no PER-vs-WER ablation showing the layer improves end-to-end accuracy.

---

## 6. Limitations

Stated in full, because the numbers above are easy to over-read.

- **Eight speakers.** This is adapted to these speakers. It is not validated as generalizing to dysarthric speech broadly.
- **No leave-one-speaker-out evaluation yet.** The headline multi-speaker result includes the test speaker in training.
- **TORGO is read speech in lab conditions.** Whether adaptation transfers to spontaneous conversational speech in a kitchen is untested and we suspect it degrades.
- **TORGO is adult acquired dysarthria** (cerebral palsy, ALS). Results should not be assumed to transfer to autism-related speech differences, which involve apraxia and prosody rather than motor weakness and produce *inconsistent* errors that per-speaker adaptation handles poorly.
- **No human-subjects testing.** No living participant has used this. All results are corpus results.
- **34.6% WER is better, not solved.** A third of the words in a sentence are still wrong.
- **Whisper hallucinates on short clips**, occasionally inventing a full sentence from a single word. Output should not be presented as verbatim without review.

CoHear is a research artifact, not a clinically validated system. It has not been evaluated in any trial or reviewed by any regulatory body. It is designed as a **listener aid** — the speaker reviews and approves output before it is shared. It should never speak for someone or assert what they meant.

---

## 7. Open questions we'd genuinely like an opinion on

1. **How much of the multi-speaker gain is transfer versus volume?** Leave-one-speaker-out is the obvious next run. Is there a better design given only 8 speakers?
2. **Is a small adapted model the right bet at all**, versus stock `large-v3`? We have not run that comparison, and it is the first question a skeptical reviewer should ask.
3. **Does phone-level intermediate representation survive dysarthric speech** well enough to be useful, given that phone recognizers share the typical-speech training bias?
4. **Is the medoid-control baseline the right way to set a noise floor?** It assumes typical speakers' variation bounds the measurement error, which feels right but we can't prove it. And with four control speakers — one of whom, MC02, sits at nearly 3× the others — we're not confident the floor is stable.
5. **Does lab read-speech adaptation transfer to spontaneous speech at all**, or does the whole result evaporate outside TORGO's conditions?
6. **Where is the line between a listener aid and a listener replacement?** At what accuracy does presenting a transcript start to substitute for the effort of listening — and is that a design constraint we should be enforcing in the interface rather than in a disclaimer?

---

## 8. Data and permissions

This work uses the TORGO Database of Acoustic and Articulatory Speech from Speakers with Dysarthria (Rudzicz, Namasivayam & Wolff, 2012). **No TORGO audio, transcripts, or speaker-level data are redistributed** — the public release contains LoRA adapter weights only. Release of those weights was reviewed and approved in advance by the TORGO maintainers, with model-card wording supplied by them. Use is non-commercial, per TORGO's terms.

> Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.
