# CoHear: adapting speech recognition to dysarthric speech

Jingjing Lei, Archbishop Mitty High School, Class of 2027
September 2026

Demo: https://huggingface.co/spaces/JJaysz/cohear
Weights: https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric
Code: https://github.com/JJayjiy/Understand-

---

## Why I started

I kept noticing the same thing in different places.

My grandma has a hard time getting to the point in situations like asking for directions. She immigrated to the US recently, and her English comes out in long, jumbled sentences that are hard for a listener to follow. Volunteering at FCSN, I saw students express ideas in ways that were clearly their own, but where the point often got lost before it landed.

Communication is not the easiest.

I wanted to know if there's a way to build a tool that helps people communicate clearly while keeping their autonomy and their interpersonal connections intact.

Those aren't one problem, and I want to be upfront that I know it. Second-language speech, developmental communication differences, and motor speech disorders have different causes and probably need different solutions. I narrowed to dysarthria for one reason: it's the case where I could actually measure whether I was helping. A public corpus exists with matched control speakers reading identical prompts, which means the effect of the speech itself can be isolated rather than guessed at.

Everything below is about dysarthria. Whether any of it reaches the situations that got me started is an open question, and I'd rather state that than paper over it.

## First I measured the gap

I used TORGO, a corpus that recorded speakers with dysarthria and control speakers reading the same prompts, in the same room, through the same microphones. That design matters. The only variable is who is speaking.

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

Those severity labels are Frenchay assessments made by clinicians in 2008, before any of this existed. They predict machine error almost perfectly. I found that unsettling. The model fails in the same order a trained human would rank difficulty, which means it isn't failing randomly. It's failing along the exact axis that already determines how much of someone's day is spent being misunderstood.

One note on reporting: about 75% of TORGO utterances are single words. I report sentence WER and single-word accuracy separately everywhere, because averaging them produces a number that means nothing.

## What I built

A LoRA adapter on `whisper-small`. I trained 3.5M of 245M parameters — 1.44% — on attention projections only.

- 2,651 utterances, 152 minutes, 8 dysarthric speakers
- 3 epochs, LR 1e-3, batch 8 × 2 accumulation
- Trained on a laptop CPU in 2.5 hours. No GPU. $0.

Evaluated on 59 held-out utterances from M04, the most impaired speaker in the corpus. No test utterance appeared in any training set.

| Model | Trained on | Sentence WER | Single-word accuracy |
|---|---|---|---|
| whisper-small, stock | — | 84.4% | 8.1% (3/37) |
| + M04 only | 24 min | 50.8% | 54.1% (20/37) |
| + 8 speakers | 152 min | **34.6%** | **67.6% (25/37)** |

Some of the individual changes, same audio, both models:

| He said | Stock Whisper heard | CoHear heard |
|---|---|---|
| storm | *dumb* | storm |
| swarm | *its one* | swarm |
| warm | *one* | warm |
| knee | *nyeh* | knee |
| feet | *deet* | feet |
| read | *what* | read |
| my sister made the flowered curtains | *my my my it took hugeapanmi the the flowering cotton din dinn* | my sister made the flowers cut thin |

The cost detail is the part I care most about. If adapting a speech model to atypical speech takes a laptop and an afternoon, then the reason this hasn't reached people isn't compute. It's data access and clinical partnership, which are different problems with different solutions.

## The result I got wrong

I expected personal data to win. Personalization is how everyone frames this, and it's what I built for first.

It lost. Eight speakers' pooled data beat M04's own 24 minutes by a wide margin — 34.6% against 50.8%.

If that holds up it's better news than what I predicted, because personalization implies enrollment. Somebody has to sit down and record a hundred phrases before the tool does anything for them. The strongest documented predictor of assistive technology abandonment is that the user wasn't involved in choosing it, and enrollment friction is exactly the kind of thing that produces that outcome. A model that works the first time someone opens it is a different product from one that asks for an hour up front.

I want to be clear about the flaw. My multi-speaker training set includes M04, so this is not a clean transfer result and I'm not claiming leave-one-speaker-out generalization. That run is still owed.

## Whether phoneme-level modeling would help

The obvious next idea is to stop predicting words directly. When a recognizer mis-hears, it commits to a wrong word and destroys the acoustic evidence — from "dumb" you cannot recover "storm." If you keep phones as an intermediate representation, in principle you can. And phone rules should scale better: there are about 44 English phonemes against tens of thousands of words, so a single rule about deleted final /t/ should repair thousands of words at once.

I believed this. Then I tried to measure it, and most of it didn't survive.

### Building a baseline first

If a system reports "this speaker deletes /s/," there are two possible causes: they did, or the tool couldn't detect it. Counting can't separate those, because both produce consistent, repeatable, speaker-specific patterns.

TORGO makes a baseline possible, because control speakers read the same prompts under the same conditions. Anything measured on them is by construction not dysarthria.

I used TORGO's own `.PHN` phone segmentations rather than a neural phone recognizer, on purpose — you can't calibrate a tool against a ruler that same tool produced. Those segmentations were hand-labelled in Wavesurfer by a registered speech-language pathologist (F. Rudzicz, personal communication, September 2026), so the reference is expert human judgment rather than machine output. That matters for interpreting the floor below: control-vs-control disagreement reflects genuine production variation between typical speakers, not a recognizer's errors.

For each of 248 shared prompts, the reference is the medoid control rendition: the control sequence with the smallest total edit distance to the other controls. Not a dictionary pronunciation. How typical speakers actually said that word in that room.

| | Phone error rate |
|---|---|
| Control vs control (noise floor) | 2.2% |
| Dysarthric vs control (signal) | 7.9% |

The floor is 27% of the signal. More than a quarter of what an uncalibrated system would report as someone's phonological pattern is something control speakers do too.

Per speaker it reproduced the severity gradient independently: M04 21.4%, M05 9.3%, controls 1.4–5.9%. Same ordering as the clinician ratings, same ordering as the word-level WER, reached by a different method at a different level of representation. Three independent measures agreeing is the best internal evidence I have.

Of 15 phones a naive "≥5% error" filter would flag, three are mostly baseline. And /ao/ inverts completely — control speakers deviate on it *more* than dysarthric speakers do. An uncalibrated pipeline would have reported "this speaker distorts /ɔ/" with confident examples, pointing the opposite direction from the truth. Every false positive was a vowel. Every robust finding was a consonant.

Where the signal is real, it's very clean. /s/ shows 25.7% error against a 0.4% floor, deleted outright 15.8% of the time. That's what you'd predict for a phone needing precise tongue grooving and sustained airflow.

### Why I'm not putting it in the product

Three things came out of that analysis that I didn't expect.

**Only 19.6% of dysarthric clips contain any phone error at all.** Four out of five are phonetically clean. But stock Whisper gets 84.4% of words wrong on the same speaker. Both cannot be true if the problem is phoneme substitution. Something below the phone level is breaking recognition — timing, duration, prosody, voice quality — and a phone rulebook can't reach any of it.

**There isn't enough error to build rules from.** 138 phone errors total across 485 clips. The largest, /s/, has 26. At three examples per rule that's maybe six rules.

**They aren't consistent enough to be rules.** /s/ goes to deletion only 62% of the time across 7 different outcomes. /t/ → /d/ holds 46% across 6. /ih/ scatters across 6 outcomes with no majority at all. A rule that fires correctly half the time isn't a repair, and a wrong hint handed to a language model can drag a correct transcript into a wrong one.

Then I joined the phone analysis to my ASR evaluation. Of the clips my tuned model still gets wrong, over half had phonetically clean speech. Among them:

> said **"write"**, heard **"right"** — twice

Those are the same phonemes. No phone-level representation can separate them, in principle, ever. Same with coupe/coop and dug/duck. Those are language-model failures, not phonetic ones.

So the phoneme layer stays out of the live pipeline. It keeps one real use: an SLP does not care about word error rate, but "deletes /s/ 16% of the time against 0.4% for matched controls" is a sentence in the vocabulary they already use every day. That's a clinical instrument, not a recognition component, and I'd rather be honest about which one it is.

## Limitations

- Eight speakers for the ASR work. Adapted to them, not shown to generalize.
- The multi-speaker result includes the test speaker in training.
- Two dysarthric speakers in the phone analysis — the only ones with head-mic phone segmentations. Four controls, all male.
- The corpus maintainers indicate the `.PHN` segmentations were hand-labelled in Wavesurfer by a registered speech-language pathologist, though they could not confirm whether forced alignment was used for any portion (F. Rudzicz, personal communication, September 2026). I have not independently verified coverage.
- Phone analysis capped at 14-phone prompts. Connected speech may behave differently.
- TORGO is adult acquired dysarthria from cerebral palsy and ALS. I would not assume this transfers to Parkinson's, and definitely not to autism-related speech differences, which involve different mechanisms.
- No human subjects. Nobody with a speech difference has used this. Every result is a corpus result.
- 34.6% WER is better, not solved. A third of the words in a sentence are still wrong.
- Whisper hallucinates on very short clips, sometimes inventing a whole sentence from one word. Output shouldn't be presented as verbatim without review.

This is a research artifact, not a clinical system. It hasn't been through any trial or regulatory review. It's built as a listener aid: the speaker reviews and approves output before it goes anywhere. It should never speak for anyone.

## Future work

A leave-one-speaker-out evaluation is the necessary next experiment: the multi-speaker result reported here includes the target speaker in training, so it does not isolate transfer from volume. A comparison against stock `large-v3` would also establish whether small-model adaptation is the right trade-off against simply using a larger model, which this work does not address.

The medoid-control baseline rests on the assumption that variation among typical speakers bounds measurement error. With four control speakers — one of whom sits at nearly three times the phone error rate of the others — the stability of that floor is not established, and a larger control pool would test it.

Finally, all results here come from read speech recorded under laboratory conditions. Whether adaptation transfers to spontaneous conversational speech is untested and is the question that most determines whether any of this is useful outside a corpus.

## Data

This used the TORGO Database of Acoustic and Articulatory Speech from Speakers with Dysarthria. No TORGO audio, transcripts, or speaker data are redistributed. The public release contains LoRA adapter weights only, and that release was reviewed and approved in advance by the TORGO maintainers. Non-commercial use, per their terms.

> Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.
