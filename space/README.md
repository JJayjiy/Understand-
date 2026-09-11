---
title: CoHear
emoji: 🗣️
colorFrom: blue
colorTo: green
sdk: gradio
app_file: app.py
pinned: false
license: apache-2.0
short_description: Making hard-to-understand speech understandable
---

# CoHear

Understand people who are hard to understand.

Whisper-small with a LoRA adapter trained on dysarthric speech from the TORGO corpus.
On the most severely affected speaker: word error rate **84.4% → 34.6%**, single-word
accuracy **8.1% → 67.6%**.

Record or upload speech and see what plain Whisper hears versus what the adapted model
hears, from the same audio.

**Research artifact, not a clinically validated system.** It has not been evaluated in any
clinical trial and has not been tested with any living participant. It assists a listener;
it does not replace one. Audio is processed and discarded.

Built by Jingjing Lei.

This model was fine-tuned using the TORGO Database of Acoustic and Articulatory Speech from
Speakers with Dysarthria. TORGO data are not included here and are subject to their original
terms of use; obtain it separately from the
[official source](http://www.cs.toronto.edu/~complingweb/data/TORGO/torgo.html). Please cite
Rudzicz, Namasivayam & Wolff (2012) when using TORGO. Non-commercial research use.
