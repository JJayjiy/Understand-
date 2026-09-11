# Demo kit — meeting today

---

## Before you leave the house (10 minutes)

- [ ] `cd ~/Desktop/Understand` → `streamlit run app.py` → **run one clip through it now.** The first clip loads the model (~30s). Do that at home so it's warm.
- [ ] Confirm the sidebar says **"Fine-tuned model loaded — models/general/merged"**
- [ ] Screenshot the app *with a successful result on screen*. That's your backup if WiFi or the demo fails.
- [ ] Have `results/side_by_side.csv` open in a tab, or the examples below printed.
- [ ] Charge your laptop. Bring the charger.
- [ ] Test that your OpenAI key still works (Stage 2 needs it).

**Assume the live demo will fail.** Then it won't matter if it does.

---

## One ethical rule for today

**Do not play TORGO audio to them.** That's recorded speech from real participants with disabilities, provided for academic use. Showing the *text* of what the system heard is fine — those are standard prompts. Playing someone's voice to a third party isn't yours to do.

So: **demo live with your own voice**, and show the TORGO results as *data*.

That distinction will also land well if they're the kind of organization that thinks about consent — which they will be.

---

## The 5-minute demo, in order

### 1. The problem (45 seconds, no laptop)

> "I've taught robotics to students with special needs for four years. What I keep running into is that my students have plenty to say and often aren't understood — not because they have nothing to communicate, but because listeners can't parse it.
>
> Speech recognition was supposed to help, and it does the opposite. It's trained on typical speech, so it works worst for the people who need it most."

### 2. The measurement (60 seconds)

> "I measured that on a research corpus called TORGO, where speakers with and without dysarthria read the *same sentences* into the *same microphones* in the same room. The only variable is who's speaking."

| | Sentence word error rate |
|---|---|
| Speakers without dysarthria | **2.9%** |
| Speakers with dysarthria | **48.0%** |

> "About sixteen times more errors. And it tracks severity almost exactly —"

| Severity | Word error rate |
|---|---|
| No dysarthria | 2.9% |
| Mild | 12.7% |
| Moderate | 29.5% |
| Severe | 77.8% |

> "Those severity ratings were made by speech-language pathologists in 2008, with no knowledge of this project. They predict the machine's failure almost perfectly."

### 3. Live demo (90 seconds)

Open the app. Speak a sentence deliberately quietly and mumbled — something ordinary:

> *"I was wondering if the pharmacy on the corner is still open."*

Show them: the raw transcript, the clarified version, and the one-sentence point. Click speak-it-back if it's working.

> "The speaker reviews it before anything is shared. It suggests; it never speaks for someone."

**If it fails:** don't apologize twice. "Let me show you the results instead" — go straight to the screenshot and section 4.

### 4. What adaptation does (90 seconds)

> "Then I adapted the model on 2.5 hours of dysarthric speech. On the most severely affected speaker in the corpus, tested on recordings the model never saw during training:"

| | Word error rate | Single words correct |
|---|---|---|
| Off-the-shelf Whisper | 84.4% | 3 of 37 |
| **After adaptation** | **34.6%** | **25 of 37** |

> "Same audio, same test, only the model changed. And it trained in two and a half hours on this laptop. No GPU, no cloud, nothing paid for."

Then show these — **read two or three out loud**:

| He said | Off-the-shelf heard | Ours heard |
|---|---|---|
| **storm** | **dumb** | **storm** |
| storm | dumb | storm |
| knee | nyeh | knee |
| swarm | its one | swarm |
| warm | one | warm |
| my sister made the flowered curtains | my my my it took hugeapanmi the the fl | my sister made the flowers cut thin |

> "A man says 'storm' and the machine hears 'dumb.' That's what this costs people — a word that isn't theirs, put in their mouth, in front of whoever's listening."

*Pause there. Don't rush past it.*

### 5. The ask (30 seconds)

> "I'm not asking for access to anyone you serve, and I'm not selling anything. I want twenty minutes of your read on where this could genuinely help — and where it could get in the way or do harm."

---

## Say these limitations before they ask

Volunteering them is what makes everything else believable.

- "34.6% is better, not solved — a third of the words are still wrong."
- "Eight speakers. I say adapted to *these* speakers, not that it generalizes."
- "Nobody with a speech difference has actually used it yet. That's why I'm here."
- "It's trained on dysarthria from cerebral palsy and ALS. It probably doesn't transfer to autism-related speech, which works differently."
- "It's a research prototype. Not a medical device."

---

## Questions they'll ask

**"How is this different from Siri or existing apps?"**
> Those are trained on typical speech — that's the 48% number. This is adapted specifically for atypical speech, and it can run entirely on a device with no internet, which matters for privacy in clinical and school settings.

**"What happens to the recordings?"**
> The local version processes on-device and stores nothing. I'd never record anyone without written consent, and I have a consent form ready. Nothing has been recorded from a person yet.

**"What if it gets it wrong?"**
> Then the speaker corrects it before it's shared — that's the design. It offers a suggestion, it never asserts. I'd rather it say "I'm not sure" than put words in someone's mouth.

**"Are you selling this?"**
> No. The training data is licensed for non-profit use only, and I plan to release the model free and open so anyone can use it.

**"Has anyone actually used it?"**
> No. That's the honest answer and it's why I'm here.

**"How long did this take?"**
> The measurement and the model, about two weeks. The training run was 2.5 hours on this laptop.

---

## Three questions to ask them

Bring these written down. Listening is the point.

1. **"Where does being understood break down most for the people you work with — and what do you do about it now?"**
2. **"If a tool like this worked, when would it actually get used? What moment?"**
3. **"What would worry you about it?"**

That third one earns more respect than anything you show them. Write the answer down verbatim.

---

## The close

> "If you ever thought this was worth trying with someone you work with — what would need to be true first?"

A question, not a request. They can't say no to it, and the answer hands you the roadmap in their own words.

---

## After

Same day, while it's fresh: log it in the Outreach tab of your tracker — who you met, what they said, next step, follow-up date. Send a two-line thank-you within 24 hours.
