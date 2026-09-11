# Stanford Parkinson's Community Outreach — brief + email

**Why they're a strong fit:** roughly 90% of people with Parkinson's develop dysarthria. Stanford's program runs community exercise classes and outreach, several of which already include voice work. The participants are adults who consent for themselves — no parental permission, no institutional gatekeeper deciding on their behalf.

**And you have a Stanford connection already** through the Doerr School YIP program. Ask that mentor for an introduction before cold-emailing. A forwarded email from inside Stanford is worth ten cold ones.

---

## The one-page brief

### CoHear — speech clarification for hard-to-understand speech

**What it does today.** You record or upload a short clip of speech. The system produces a clearer written version, and optionally speaks it aloud in a clear voice. The speaker reviews and approves the result before anything is shared. It runs in a web browser, and a version runs entirely on-device with no internet connection.

**What we measured.** Using the TORGO research corpus — dysarthric and non-dysarthric speakers recorded with identical prompts, microphones, and room conditions — we found that off-the-shelf speech recognition (OpenAI's Whisper) makes about **16× more errors** for speakers with dysarthria:

| Speaker group | Sentence word error rate |
|---|---|
| Control | 2.9% |
| Dysarthric | 48.0% |

The failure scales cleanly with clinical severity:

| Severity (Frenchay intelligibility) | Word error rate |
|---|---|
| Control | 2.9% |
| Mild | 12.7% |
| Moderate | 29.5% |
| Severe | 77.8% |

Those severity ratings were assigned by speech-language pathologists in 2008, entirely independent of this work. They predict machine error rate almost exactly.

**What we built.** We adapted Whisper using LoRA on 2.5 hours of dysarthric speech, training under 1.5% of the model's parameters. On the most severely affected speaker in the corpus, held out from training:

| | Word error rate | Single-word accuracy |
|---|---|---|
| Stock Whisper | 84.4% | 8.1% (3 of 37 words) |
| Adapted | **34.6%** | **67.6% (25 of 37 words)** |

Training took 2.5 hours on a laptop CPU. No GPU, no cloud, no cost. The point of that detail is that adapting speech technology to atypical speech no longer requires a research lab — which matters for whether this can ever reach people at scale.

**An unexpected result.** A model trained on eight speakers outperformed one trained only on the target speaker's own 24 minutes. That suggests a shared model can help someone **without any enrollment** — no recording hundreds of phrases before the tool works.

### What we honestly don't know

**TORGO is dysarthria from cerebral palsy and ALS. It contains no Parkinson's speech.** Parkinsonian dysarthria is hypokinetic — reduced loudness, monotone pitch, rushed rate — which is a different profile from the speakers we trained on. Whether our adaptation transfers is genuinely unknown.

We would rather find that out from people who work with Parkinson's every day than assume it.

### Limitations we state plainly

- 34.6% word error is better, not solved. A third of words are still wrong.
- Eight speakers is a small sample. We say "adapted to these speakers," not "generalizes."
- No one with a speech difference has used this yet. All results are on a research corpus.
- It assists a listener; it does not replace one, and it is not a medical device.

### What we're asking for

1. **Twenty minutes** with someone on your team to hear where this could help and where it could get in the way.
2. **Whether it transfers to Parkinson's speech** — your read on that, before we assume it does.
3. **If it seems worth it later**, a chance to show it at a class or group where people can choose to try it themselves.

We are not asking for participant contact information, and we are not selling anything.

---

## The email

**Subject:** High school project on speech clarification — would it help with Parkinson's speech?

Dear [Name],

My name is Jingjing Lei. I'm a senior at Archbishop Mitty in San Jose, and I was a research intern this summer with the Stanford Doerr School's Young Investigators Program.

With a project partner, I've built a tool that takes hard-to-understand speech and produces a clearer version. Using the TORGO research corpus, we measured that stock speech recognition makes about 16 times more errors for speakers with dysarthria than for control speakers reading the same sentences into the same microphones. We then adapted the model and cut word error rate from 84.4% to 34.6% on the most severely affected speaker.

I'm writing because of something we can't answer ourselves. **Our training data is dysarthria from cerebral palsy and ALS — there is no Parkinson's speech in it.** Parkinsonian dysarthria has a different profile, and we don't know whether our work transfers. We'd rather ask people who work with it daily than assume.

I'm not asking for participant contact information and I'm not selling anything. I'd like 20 minutes with someone on your team to hear where a tool like this could genuinely help, and where it could get in the way.

I've attached a one-page summary with our measurements and our limitations. Happy to come to Stanford, or talk by phone or video, whenever is convenient.

Thank you for your time,

Jingjing Lei
Archbishop Mitty High School, Class of 2027
[phone] · [email]

---

## Notes on why this works

- **Leading with the thing you don't know** is the strongest move available to you. Researchers and clinicians are used to students overclaiming. Opening with a genuine gap in your knowledge marks you as someone worth talking to.
- **The severity gradient is your credibility.** It shows you didn't just run a model — you found structure in the data and connected it to clinical assessment.
- **Attach the one-pager here** (unlike a cold clinic email). You have a Stanford connection and a research framing; a brief is expected.
- **Use your YIP contact first.** Ask them to forward it. Internal referrals get answered.
