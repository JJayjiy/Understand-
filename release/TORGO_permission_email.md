# Email to the TORGO maintainer — before releasing model weights

**To:** Frank Rudzicz — frank@cs.toronto.edu (listed on the TORGO page)
**Subject:** Permission question — releasing LoRA adapter weights trained on TORGO

---

Dear Dr. Rudzicz,

I'm a high school student in San Jose, California, working on speech recognition for dysarthric speech with a project partner. We've been using the TORGO database, and I wanted to ask permission before doing anything with the results.

Using TORGO, we fine-tuned OpenAI's Whisper-small with a LoRA adapter on the eight dysarthric speakers. On held-out utterances from M04, sentence-level word error rate fell from 84.4% to 34.6%, and single-word accuracy rose from 8.1% to 67.6%. Training took 2.5 hours on a laptop CPU.

We'd like to release the **adapter weights** publicly and free of charge, so that speech-language pathologists, families, and other students can use and build on them. To be clear about what this would and would not include:

- **Would be released:** LoRA adapter weights (a few MB), our training and evaluation code, and a report of results.
- **Would not be released:** any TORGO audio, transcripts, or annotations. No portion of the database would be redistributed.

I understand TORGO is free for academic and non-profit purposes, and that any publication must cite your work — we cite Rudzicz, Namasivayam & Wolff (2012) throughout, and will continue to. My questions:

1. Does releasing derived model weights, with no data included, fall within the academic/non-profit terms?
2. Is there wording you'd like included in the model card regarding TORGO?
3. Is there anything about this you'd prefer we not do?

If releasing weights isn't appropriate, we'll publish only the code and results and leave the weights unreleased.

Thank you for making TORGO available. It's the reason a high school student could work on this at all, and the Frenchay assessments included in the speaker notes turned out to be one of the most useful parts — the clinical intelligibility ratings predict machine error rate almost exactly, which became a finding in itself.

Sincerely,
Jingjing Lei
Archbishop Mitty High School, Class of 2027
San Jose, California
[email] · [project link, if you have one]

---

## Notes

**Send this before uploading anything.** Weights are hard to un-publish.

**Why this email is likely to get a yes:** it's specific about what you'd release, explicit about what you wouldn't, shows you read the license, and offers to comply either way. It also gives him something interesting — the Frenchay/WER correlation is a finding about *his* corpus that he may not have seen.

**If he doesn't reply in ~2 weeks:** release the code, the report, and the results without the weights. Anyone with TORGO access can reproduce the model in 2.5 hours using your scripts. That preserves nearly all the impact with none of the risk.

**Commercial use is separately restricted.** "Academic (non-profit)" means a TORGO-trained model can't be a commercial product. If CoHear becomes a venture, the model would need retraining on differently-licensed data. Worth knowing before any Diamond Challenge pitch.

## Required citation — include in every publication, model card, and report

> Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.
