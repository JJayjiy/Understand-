# CoHear: adapting speech recognition to dysarthric speech, and what I found out about measuring it

Jingjing Lei, Archbishop Mitty High School, Class of 2027
With Melodie Lee (phonological analysis)
September 2026

Demo: https://huggingface.co/spaces/JJaysz/cohear
Weights: https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric
Code: https://github.com/JJayjiy/Understand-

---

## Why I started

I kept noticing the same thing in different places. My grandmother takes a long time to get to the point and people stop listening. A friend of mine has a speech difference, and I realized nobody had ever really asked him what he wanted. At a center for special-needs students, I watched staff who clearly cared spend most of a conversation just trying to work out what was being said.

The common thread wasn't the speaker. It was that understanding someone takes time, and most situations don't give you that time.

So I wanted to know whether speech recognition could give some of that time back. And before building anything, I wanted to know how badly it currently fails.

## First I measured the gap

I used TORGO, a corpus that recorded speakers with dysarthria and control speakers reading the same prompts, in the same room, through the same microphones. That design matters. It means the only variable is who is speaking.

Off-the-shelf `whisper-small`:

| Speaker group | Sentence WER |
|---|---|
| Control (894 clips) | 2.9% |
| Dysarthric (468 clips) | 48.0% |

About 16× worse, with everything else held constant.

It also scales with clinical severity:

| Severity | Sentence WER | Single-word accuracy |
|---|---|---|
| Control | 2.9% | 71.3% |
| Mild | 12.7% | 62.2% |
| Moderate | 29.5% | 42.1% |
| Severe | 77.8% | 12.9% |

Those severity labels are Frenchay assessments made by clinicians in 2008, before any of this existed. They predict machine error almost perfectly. I found that unsettling. The model is failing in the same order a trained human would rank difficulty, which suggests it isn't failing randomly.

One note on reporting: about 75% of TORGO utterances are single words. I report sentence WER and single-word accuracy separately everywhere, because averaging them together produces a number that means nothing.

## What I built

A LoRA adapter on `whisper-small`. I trained 3.5M of 245M parameters, which is 1.44%, on attention projections only.

- 2,651 utterances, 152 minutes, 8 dysarthric speakers
- 3 epochs, LR 1e-3
- Trained on a laptop CPU in 2.5 hours, no GPU, $0

Evaluated on 59 held-out utterances from M04, the most impaired speaker in the corpus. No test utterance was in any training set.

| Model | Trained on | Sentence WER | Single-word accuracy |
|---|---|---|---|
| whisper-small, stock | — | 84.4% | 8.1% (3/37) |
| + M04 only | 24 min | 50.8% | 54.1% (20/37) |
| + 8 speakers | 152 min | **34.6%** | **67.6% (25/37)** |

The cost detail is the part I care most about. If adapting a speech model to atypical speech takes a laptop and an afternoon, then the reason this hasn't reached people isn't compute. It's data access and clinical partnership, which are different problems with different solutions.

## The result I got wrong

I expected personal data to win. Personalization is how everyone frames this, and it's what I built for first.

It lost. Eight speakers' pooled data beat M04's own 24 minutes by a wide margin.

If that holds up, it's better news than what I predicted, because personalization implies enrollment. Somebody has to sit down and record a hundred phrases before the tool does anything for them. The strongest documented predictor of assistive technology abandonment is that the user wasn't involved in choosing it, and enrollment friction is exactly the kind of thing that produces that outcome. A model that works on day one without setup is a different product.

I want to be clear about the flaw: my multi-speaker training set includes M04. So this is not a clean transfer result and I'm not claiming leave-one-speaker-out generalization. That run is still owed.

## The linguistics layer, and what happened when I tested it

My collaborator Melodie built a phoneme-level layer. The reasoning was that when a recognizer mis-hears, it commits to a wrong word and destroys the acoustic evidence. From "dumb" you can't get back to "storm." If you keep phones as an intermediate step, you can. And phone rules should scale better: there are ~44 English phonemes but tens of thousands of words, so one rule about deleted final /t/ should repair thousands of words at once.

I believed this. Then I tried to measure it, and most of it didn't survive.

### Building a baseline first

Before trusting any phonological pattern, I wanted to know how much of it was real. If a tool reports "this speaker deletes /s/," there are two possible causes: they did, or the tool couldn't detect it. Counting can't separate those, because both produce consistent, repeatable, speaker-specific patterns.

TORGO makes a baseline possible, because control speakers read the same prompts in the same conditions. Anything you measure on them is by construction not dysarthria.

I used TORGO's own `.PHN` phone segmentations rather than a neural phone recognizer, on purpose. You can't calibrate a tool against a ruler that same tool produced. For each of 248 shared prompts, the reference is the medoid control rendition, meaning the control sequence with the smallest total edit distance to the other controls. Not a dictionary pronunciation. How typical speakers actually said that word in that room.

| | Phone error rate |
|---|---|
| Control vs control (noise floor) | 2.2% |
| Dysarthric vs control (signal) | 7.9% |

The floor is 27% of the signal. More than a quarter of what an uncalibrated system would report as someone's phonological pattern is something control speakers do too.

Per speaker, it reproduced the severity gradient independently: M04 21.4%, M05 9.3%, controls 1.4–5.9%. Same ordering as the clinician ratings, same ordering as the word-level WER, arrived at by a different method at a different level. Three independent measures agreeing is the best internal evidence I have.

Of 15 phones that a naive "≥5% error" filter would flag, three are mostly baseline. And /ao/ inverts completely: control speakers deviate on it *more* than dysarthric speakers do. An uncalibrated pipeline would have reported "this speaker distorts /ɔ/" with confident examples, pointing the opposite direction from the truth. Every false positive was a vowel. Every robust finding was a consonant.

The real signal is clean where it exists. /s/ shows 25.7% error against a 0.4% floor, and is deleted outright 15.8% of the time. That's what you'd predict for a phone needing precise tongue grooving and sustained airflow.

### Why I'm not shipping the layer

Three things came out of that analysis that I didn't expect.

**Only 19.6% of dysarthric clips contain any phone error at all.** Four out of five are phonetically clean. But stock Whisper gets 84.4% of words wrong on the same speaker. Both can't be true if the problem is phoneme substitution. Something below the phone level is breaking recognition: timing, duration, prosody, voice quality. A phone rulebook can't reach any of it.

**There isn't enough error to build rules from.** 138 phone errors total across 485 clips. The largest, /s/, has 26. At three examples per rule you get maybe six rules.

**And they aren't consistent enough to be rules.** /s/ → deleted only 62% of the time across 7 different outcomes. /t/ → /d/ 46% across 6. /ih/ scatters across 6 outcomes with no majority. A rule that fires correctly half the time isn't a repair, and a wrong hint passed to a language model can drag a correct transcript into a wrong one.

Then I joined the phone analysis to my ASR evaluation. Of the clips my tuned model still gets wrong, over half had phonetically clean speech. Among them:

> said **"write"**, heard **"right"** (twice)

Those are the same phonemes. No phone-level representation can separate them, in principle. Same with coupe/coop and dug/duck. Those are language-model failures, not phonetic ones.

So I'm cutting the layer from the live pipeline and keeping it as an offline analysis tool and as a clinical interface. An SLP does not care about word error rate, but "deletes /s/ 16% of the time against 0.4% for matched controls" is a sentence in the vocabulary they already use.

I want to say clearly that this doesn't make the layer a waste. Melodie's design required a human to confirm every mismatch before it counted as evidence, specifically because automatic phone recognizers are also trained on typical speech and would otherwise write their own failures down as facts about a disabled person's speech. That gate is why the /ao/ false positive got caught instead of shipped. The finding is the contribution.

## Limitations

- Eight speakers for the ASR work. Adapted to them, not shown to generalize.
- The multi-speaker result includes the test speaker in training.
- Two dysarthric speakers in the phone analysis, the only ones with head-mic phone segmentations. Four controls, all male.
- I don't know how TORGO's `.PHN` files were produced. If they were forced-aligned with a typical-speech model rather than hand-labelled, phone errors are undercounted and my first finding weakens.
- Phone analysis capped at 14-phone prompts. Connected speech may differ.
- TORGO is adult acquired dysarthria from cerebral palsy and ALS. I would not assume this transfers to Parkinson's, and definitely not to autism-related speech differences, which involve different mechanisms.
- No human subjects. Nobody with a speech difference has used this. All results are corpus results.
- 34.6% WER is better, not solved. A third of the words in a sentence are still wrong.

This is a research artifact and not a clinical system. It hasn't been through any trial or any regulatory review. It's built as a listener aid: the speaker reviews and approves output before it goes anywhere. It shouldn't speak for anyone.

## What I'd like to be told I'm wrong about

1. How much of the multi-speaker gain is transfer and how much is just volume? Leave-one-speaker-out is the obvious run, but with eight speakers I'm not sure it tells me much.
2. Is a small adapted model even the right bet, versus stock `large-v3`? I haven't run that, and it's the first thing a skeptic should ask.
3. Is the medoid-control baseline a sound way to set a noise floor? It assumes typical speakers' variation bounds measurement error. With four controls, one of whom sits at nearly 3× the others, I don't know if the floor is stable.
4. Does lab read-speech adaptation transfer to spontaneous speech at all, or does this evaporate outside TORGO's conditions?
5. Where's the line between a listener aid and a listener replacement? At what accuracy does showing someone a transcript start to substitute for the work of listening, and should that be enforced in the interface instead of a disclaimer?

## Data

This used the TORGO Database of Acoustic and Articulatory Speech from Speakers with Dysarthria. No TORGO audio, transcripts, or speaker data are redistributed. The public release contains LoRA adapter weights only, and that release was reviewed and approved in advance by the TORGO maintainers. Non-commercial use, per their terms.

> Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.
