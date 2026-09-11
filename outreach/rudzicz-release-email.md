# Reply to Frank Rudzicz — release announcement

Send as a reply in the existing thread.

---

Hi Frank,

Thank you again — I used your wording verbatim.

It's live:

- **Demo:** https://huggingface.co/spaces/JJaysz/cohear
- **Weights:** https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric

Adapter weights only, no TORGO data. It's a LoRA adapter on `whisper-small` — 1.44% of parameters, 152 minutes from eight speakers, trained on a laptop CPU. On held-out M04, sentence WER went from 84.4% to 34.6% and single-word accuracy from 8.1% to 67.6%.

One question I couldn't answer from the documentation: **how were the `.PHN` files produced?** I used them to set a control baseline — control-vs-control phone disagreement came out at 2.2% against a 7.9% dysarthric signal. But if they were forced-aligned with a typical-speech model rather than hand-labelled, my floor is too low and I should say so.

No reply needed. Mostly I wanted you to see it working.

Thank you for making TORGO available, and for taking the email seriously.

Jingjing Lei

---

## Notes

- **Cut the compliance paragraph.** You were right — he set the conditions, you met them, and the model card is public. Reciting it back sounds like a student showing their work. "Adapter weights only, no TORGO data" is enough; he can check in ten seconds if he cares.
- **The `.PHN` question is the whole point.** It's real, it affects a published number, and he's one of very few people who can answer. "No reply needed" makes a reply more likely, not less.
- **No ask.** This email closes the loop he opened. If he wants more contact, he'll open that door.
