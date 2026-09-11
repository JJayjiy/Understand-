# CoHear

**Making hard-to-understand speech understandable.**

Jingjing Lei · Archbishop Mitty High School · Try it: https://huggingface.co/spaces/JJaysz/cohear

---

## Our purpose

Understanding someone takes time, and most situations don't give you that time.

That's the problem we're working on. Not speech as a medical condition — speech as the thing that decides whether a person gets to be part of a conversation. When someone is hard to understand, what they lose isn't clarity. It's the room's patience.

Speech recognition should help with exactly this. Instead it does the opposite, because it was built almost entirely from typical speech. It works worst for the people who would get the most out of it.

## What we measured

We used a research corpus where speakers with and without dysarthria read the same prompts, in the same room, through the same microphones. The only thing that changes is who is speaking.

| | Words the system gets wrong |
|---|---|
| Speakers without dysarthria | **2.9%** |
| Speakers with dysarthria | **48.0%** |

Sixteen times worse.

The failure scales with clinical severity, and the severity ratings were made by speech-language pathologists in 2008, entirely independent of our work:

| Severity | Words wrong |
|---|---|
| Control | 2.9% |
| Mild | 12.7% |
| Moderate | 29.5% |
| Severe | 77.8% |

The technology fails along the exact axis that already determines how much of someone's day is spent being misunderstood. It's steepest for the people furthest up that curve.

## What we built

We retrained a small part of an existing speech model — 1.44% of its parameters — on 2.5 hours of dysarthric speech. On the most severely affected speaker in the corpus, on recordings held out from training:

| | Words wrong | Single words correct |
|---|---|---|
| Before | 84.4% | 3 of 37 |
| After | **34.6%** | **25 of 37** |

That training took 2.5 hours on a laptop. No GPU, no cloud, no cost.

We think that detail matters more than the accuracy number. If adapting speech technology to someone's voice costs an afternoon and nothing else, then the reason it hasn't reached people isn't the technology. It's that nobody has sat down with them.

**One result we didn't expect:** a model trained on eight different speakers worked better than one trained on the target speaker's own recordings. That points toward something that helps the first time someone opens it, with no setup — no recording a hundred phrases before the tool does anything.

## Our goal

**An app on the speaker's own phone that turns what they said into clear text in about two seconds, that they alone decide whether to show — and that works the first time they open it, with no setup.**

Concretely, that means four things:

1. **The speaker holds the phone.** Not the caregiver, not the clinician. This is a tool someone uses to be understood, not a tool used on them.
2. **No enrollment.** No recording a hundred phrases before it does anything. Our results suggest a shared model can work for a new person on day one, which is the difference between a tool people try and a tool people finish setting up.
3. **Nothing is shared until the speaker shares it.** The transcript is private to their screen. Showing it, or having it read aloud, is a deliberate act they take — one large button.
4. **It never speaks for them.** It helps a listener understand. It does not decide what someone meant.

That last rule isn't only an ethical stance. The strongest documented predictor of assistive technology being abandoned is that the user wasn't involved in choosing it — technology picked *for* someone rather than *with* them. Keeping the speaker in control is a design requirement, not a courtesy.

**Where we are:** the model is public and working in a browser today. We're building it into an installable app over the next month, and the first version will go to a small number of real users rather than a launch.

## Where this stands

**The corpus we trained on contains no Parkinson's speech.** It's dysarthria from cerebral palsy and ALS. Parkinsonian dysarthria is different in kind — reduced loudness, monotone pitch, rushed rate. We have not tested whether any of this transfers, and we won't claim it does.

And stated plainly:

- 34.6% wrong is better, not solved. A third of words in a sentence are still wrong.
- Eight speakers is a small sample. We say "adapted to these speakers," not "works for everyone."
- **No one with a speech difference has used this yet.** Every result is from a research corpus.
- It is not a medical device and has not been through any clinical or regulatory review.

## Why we're writing

We'd like twenty minutes to share where this is and where we're taking it, with people who see this population every day.

Everything above came from a corpus. At some point that stops being enough, and the work has to meet the people it's supposed to be for. We'd rather that happen early, while the design can still change.

The model and a working demo are public at the link above — no signup, no install. It's easier to react to than to describe.
