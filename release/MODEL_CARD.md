---
license: apache-2.0
language: en
tags:
  - automatic-speech-recognition
  - whisper
  - dysarthria
  - accessibility
  - atypical-speech
  - lora
  - peft
base_model: openai/whisper-small
datasets:
  - TORGO
metrics:
  - wer
---

# CoHear — Whisper-small adapted for dysarthric speech

A LoRA adapter for `openai/whisper-small`, fine-tuned on dysarthric speech from the TORGO corpus.

**On the most severely affected speaker in TORGO, word error rate falls from 84.4% to 34.6% — a 59% relative reduction. Single-word accuracy rises from 8.1% to 67.6%.**

Built by Jingjing Lei (Archbishop Mitty High School) as part of CoHear, a project on making hard-to-understand speech understandable.

---

## Why this exists

Speech recognition is trained overwhelmingly on typical speech, so it fails worst for the people who would benefit most. Measured on TORGO under identical conditions — same prompts, same microphones, same room — stock `whisper-small` gets:

| Speaker group | Sentence WER |
|---|---|
| Control (non-dysarthric) | **2.9%** |
| Dysarthric | **48.0%** |

A ~16× difference where the only variable is who is speaking.

The failure scales with clinical severity:

| Severity | Sentence WER | Word accuracy |
|---|---|---|
| Control | 2.9% | 71.3% |
| Mild | 12.7% | 62.2% |
| Moderate | 29.5% | 42.1% |
| Severe | 77.8% | 12.9% |

Severity labels come from clinician assessments recorded with the corpus in 2008, independent of this work. They predict machine error rate almost exactly.

---

## Results

All evaluated on 59 held-out utterances from speaker M04 (rated most impaired in the corpus). Same test set, same normalization, only the model differs. **No test utterance was seen during training.**

| Model | Trained on | Sentence WER | Word accuracy |
|---|---|---|---|
| `whisper-small` (stock) | — | 84.4% | 8.1% (3/37) |
| + single-speaker LoRA | M04 only, 24 min | 50.8% | 54.1% (20/37) |
| **+ multi-speaker LoRA (this model)** | 8 speakers, 152 min | **34.6%** | **67.6% (25/37)** |

### The finding worth noting

**Pooled data from other dysarthric speakers outperformed personal data alone.** Training on eight speakers beat training on the target speaker's own 24 minutes — by a wide margin.

This matters practically: it suggests a shared model can help a new user **without enrollment**. Nobody has to record hundreds of phrases before the tool works. Given that user burden is a documented driver of assistive-technology abandonment, that difference may matter more than the accuracy number.

Caveat: the multi-speaker model's training data *includes* M04, so this is not a clean transfer experiment. A leave-one-speaker-out evaluation is needed to isolate how much comes from transfer versus volume.

---

## Usage

```python
from transformers import WhisperProcessor, WhisperForConditionalGeneration
from peft import PeftModel
import soundfile as sf, torch

base = WhisperForConditionalGeneration.from_pretrained("openai/whisper-small")
base.config.forced_decoder_ids = None
base.config.suppress_tokens = []

model = PeftModel.from_pretrained(base, "<this-repo>").merge_and_unload()
proc = WhisperProcessor.from_pretrained("openai/whisper-small",
                                        language="english", task="transcribe")

audio, sr = sf.read("clip.wav", dtype="float32")   # 16 kHz mono
feats = proc.feature_extractor(audio, sampling_rate=16000,
                               return_tensors="pt").input_features
ids = model.generate(feats,
                     forced_decoder_ids=proc.get_decoder_prompt_ids(
                         language="english", task="transcribe"),
                     max_new_tokens=200)
print(proc.batch_decode(ids, skip_special_tokens=True)[0])
```

**Always set `language="en"` explicitly.** Whisper frequently misdetects the language on atypical speech and will transcribe an English speaker as another language entirely.

---

## Training

- **Base:** `openai/whisper-small` (244M parameters)
- **Method:** LoRA on attention projections (`q_proj`, `v_proj`), r=32, alpha=64, dropout=0.05
- **Trainable parameters:** 3.5M of 245M (**1.44%**)
- **Data:** 2,651 utterances / 152 minutes, 8 dysarthric speakers (TORGO: F01, F03, F04, M01–M05)
- **Epochs:** 3 · **LR:** 1e-3 · **Batch:** 8 × 2 accumulation
- **Hardware:** laptop CPU. **2.5 hours. No GPU. $0.**

That last line is the point. Adapting a speech model to atypical speech no longer requires a research lab.

---

## Limitations — please read before deploying

- **Eight speakers.** This is adapted to these speakers, not validated as generalizing to dysarthric speech broadly.
- **TORGO is adult acquired dysarthria** (cerebral palsy, ALS). Results do **not** transfer to autism-related speech differences, which involve apraxia and prosody rather than motor weakness and produce *inconsistent* errors that per-speaker adaptation handles poorly.
- **~75% of TORGO utterances are single words.** Sentence WER and single-word accuracy are reported separately throughout; a blended average would be meaningless.
- **No human-subjects testing.** All results are on a research corpus. No living participants have used this.
- **34.6% WER is better, not solved.** A third of words in a sentence are still wrong. This assists a listener; it does not replace one.
- **Whisper hallucinates on short clips.** On very short single-word audio it sometimes invents a whole sentence. Do not present output as verbatim without review.

---

## Intended use

A **listener aid**: the speaker reviews and approves output before it is shared. It should never speak for someone or assert what they meant.

That isn't only an ethical stance. The strongest documented predictor of assistive-technology abandonment is *lack of consideration of user opinion in device selection* — technology chosen for someone rather than with them. Keeping the speaker in control is a design requirement, not a courtesy.

**Not for:** medical decisions, legal proceedings, or any setting where a misrecognition carries consequences the speaker cannot contest.

---

## Data

This model was fine-tuned using the TORGO Database of Acoustic and Articulatory Speech from Speakers with Dysarthria. TORGO data are not included in this repository and are subject to their original terms of use. Users wishing to access TORGO should obtain it separately from the [official source](http://www.cs.toronto.edu/~complingweb/data/TORGO/torgo.html). Please cite Rudzicz, Namasivayam & Wolff (2012) when using TORGO.

> Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.

**This repository contains LoRA adapter weights only.** No TORGO audio, transcripts, annotations, or speaker-level data are included, and nothing here permits reconstruction of the original dataset. TORGO is not redistributed and remains subject to its own terms.

Release of these adapter weights was reviewed and approved in advance by the TORGO maintainers.

**Non-commercial.** TORGO's terms permit academic and non-profit use only. This model is released for research and free public use, and is not licensed for commercial deployment.

## This is a research artifact, not a clinical system

**CoHear has not been clinically validated.** It has not been evaluated in any clinical trial, has not been reviewed or cleared by any regulatory body, and has not been tested with any living participant. All results reported here come from a research corpus.

If you are a speech-language pathologist, caregiver, or family member: this may be interesting to explore, but it is **not** a validated clinical tool and should not be used to make clinical decisions, to determine what someone meant in any consequential setting, or as a substitute for professional assessment. It assists a listener. It does not replace one.

## Citation

```bibtex
@misc{cohear2026,
  title  = {CoHear: Low-cost adaptation of Whisper for dysarthric speech},
  author = {Lei, Jingjing},
  year   = {2026},
  note   = {Archbishop Mitty High School}
}
```

## License

Apache 2.0 (model weights). TORGO data remains under its own terms.
