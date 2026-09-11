# Releasing CoHear

Three things, in this order. The whole thing is about two hours.

---

## Why not a landing page

A landing page markets something people can't use. What you want is a place where someone can **try it in their browser in thirty seconds** — which is a Hugging Face Space. It hosts your model, gives you a public URL, is free, and doubles as the demo for competitions.

A Space *is* the landing page, and it's the only version anyone can act on. Build the page later if you ever need one; the Space comes first.

---

## 1. Publish the model (~20 min)

Create an account at **huggingface.co**, then:

```bash
pip install huggingface_hub
huggingface-cli login          # paste an access token from Settings → Access Tokens
```

Create a model repo named `cohear-whisper-small-dysarthric`, then push the adapter (a few MB, not the full merged model):

```bash
cp release/MODEL_CARD.md models/general/adapter/README.md

python -c "
from huggingface_hub import HfApi
HfApi().upload_folder(
    folder_path='models/general/adapter',
    repo_id='YOUR-USERNAME/cohear-whisper-small-dysarthric',
    repo_type='model')
print('uploaded')
"
```

**Upload the adapter, not `merged/`.** The adapter is small and makes clear what's yours versus what's OpenAI's. `MODEL_CARD.md` becomes the repo's front page.

---

## 2. Build the Space — where people try it (~40 min)

New Space → **Gradio** SDK → free CPU tier. Two files:

**`requirements.txt`**
```
transformers
peft
torch
soundfile
librosa
gradio
```

**`app.py`**
```python
import gradio as gr, torch, soundfile as sf, librosa
from transformers import WhisperProcessor, WhisperForConditionalGeneration
from peft import PeftModel

REPO = "YOUR-USERNAME/cohear-whisper-small-dysarthric"
proc = WhisperProcessor.from_pretrained("openai/whisper-small",
                                        language="english", task="transcribe")
base = WhisperForConditionalGeneration.from_pretrained("openai/whisper-small")
base.config.forced_decoder_ids = None; base.config.suppress_tokens = []
tuned = PeftModel.from_pretrained(base, REPO).merge_and_unload().eval()
stock = WhisperForConditionalGeneration.from_pretrained("openai/whisper-small").eval()
forced = proc.get_decoder_prompt_ids(language="english", task="transcribe")

def run(path):
    if not path:
        return "", ""
    audio, sr = sf.read(path, dtype="float32")
    if audio.ndim > 1: audio = audio.mean(axis=1)
    if sr != 16000: audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)
    feats = proc.feature_extractor(audio, sampling_rate=16000,
                                   return_tensors="pt").input_features
    out = []
    for m in (stock, tuned):
        with torch.no_grad():
            ids = m.generate(feats, forced_decoder_ids=forced, max_new_tokens=200)
        out.append(proc.batch_decode(ids, skip_special_tokens=True)[0].strip())
    return out[0], out[1]

gr.Interface(
    fn=run,
    inputs=gr.Audio(sources=["microphone", "upload"], type="filepath",
                    label="Record or upload speech"),
    outputs=[gr.Textbox(label="Stock Whisper heard"),
             gr.Textbox(label="CoHear heard")],
    title="CoHear — speech clarification for dysarthric speech",
    description=("Stock Whisper vs. our adapted model, side by side. "
                 "On the most severely affected speaker in TORGO, word error "
                 "fell from 84.4% to 34.6%.\n\n"
                 "Your audio is processed and discarded — nothing is stored. "
                 "This is a research prototype, not a medical device."),
    flagging_mode="never",
).launch()
```

**The side-by-side is the whole design.** One recording, two transcripts, difference visible instantly. That's your demo video, your competition submission, and your outreach link in one URL.

---

## 3. The technical report (~1 hour)

Write it once; it serves as the STS paper draft, the CAC write-up, and the thing you send to SLPs.

**Structure:**

1. **Problem** — 2.9% vs 48.0% under identical conditions. The severity gradient. Independent clinician labels predicting machine failure.
2. **Method** — LoRA, 1.44% of parameters, laptop CPU, $0.
3. **Results** — the three-condition table. Report sentence WER and word accuracy separately, always.
4. **The surprising finding** — pooled data beat personal data; what that implies for deployment without enrollment.
5. **Limitations** — the full list from the model card. Do not soften them.
6. **What it doesn't solve** — the institutional barriers: Medicare's device/software split, the one-SGD-per-patient rule, the SLP prescription gate, 29.3% abandonment.

That last section is what separates this from a school project. Anyone can report a number. Explaining why the number isn't enough is the harder, more honest thing.

Host it as `REPORT.md` in the GitHub repo. Permanent, citable, no gatekeeper.

---

## Before you publish — the checklist

- [ ] No TORGO audio anywhere in the repos. Weights only.
- [ ] Limitations section intact and prominent.
- [ ] "Research prototype, not a medical device" on the Space.
- [ ] "Audio is processed and discarded" — and make sure that's actually true.
- [ ] Authorship correct on model card, Space, and report.
- [ ] Check TORGO's terms allow releasing derived model weights. If unclear, email the maintainers before pushing.

That last one matters. Ask first; it costs an email and protects the release.

---

## What order this actually happens in

Model → Space → report. After the Space exists you have a link, and the link changes every conversation: SLPs can try it before meeting you, competition judges can use it, and your outreach emails get much easier to answer.
