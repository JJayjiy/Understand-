# Intro email — researcher / professor

**Ask:** advice and an open door. Not a pilot, not a partnership, not a favor.

---

## Before you send — three rules

**1. The one line you must customize.** Replace the bracketed sentence in paragraph one with something specific from *their* work — a paper title, a finding, a method. Not "your work on speech technology." If you can't fill that line honestly, you're emailing the wrong person, or you need to read one of their papers first. Twenty minutes on an abstract is the difference between a reply and no reply.

**2. Lead with uncertainty, not with the result.** Counterintuitive but reliable: academics reply to questions they can answer, far more than to accomplishments they're asked to admire. The email below spends its best real estate on what you *don't* know. That's the hook.

**3. Never attach the brief to a cold email.** Attachments from unknown senders don't get opened. Link it. Offer to send it. Let them ask.

---

## The email

**Subject:** High schooler adapting Whisper to dysarthric speech — a question about your work on [specific topic]

---

Dear Professor [Last Name],

I'm a senior at Archbishop Mitty High School in San Jose. I've spent the last few months on speech recognition for dysarthric speech, and I've hit a question I can't resolve on my own — [one specific sentence about their work and why it's the reason you're writing them and not someone else].

The short version of what I have: on TORGO, under identical recording conditions, stock Whisper-small gets 2.9% WER on control speakers and 48.0% on dysarthric speakers. I trained a LoRA adapter — 1.44% of parameters, on a laptop CPU, 2.5 hours, no GPU — and on the most severely affected speaker word error fell from 84.4% to 34.6%. The weights and a live side-by-side demo are public.

The result I'd most like to be wrong about: **pooled data from eight speakers beat the target speaker's own data**, which contradicts the personalization framing I started with. The obvious caveat is that my multi-speaker training set includes the test speaker, so it isn't a clean transfer experiment — I know leave-one-speaker-out is the run I owe. But with only eight speakers I'm not sure that design tells me much either, and I'd rather ask someone who's thought about this than guess.

My partner has also built a phoneme-level layer on top (Allosaurus for produced phones, gruut for expected, panphon for articulatory feature distance). We gated it on human review — an automatic mismatch only enters a speaker's profile if a person confirms it's a speaker pattern and not a recognizer error — because Allosaurus is also trained mostly on typical speech and we didn't want to attribute its failures to someone's speech. We're not sure that's the right call, and it's the second thing I'd want to ask you about.

Demo: https://huggingface.co/spaces/JJaysz/cohear
Weights: https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric

Would you be open to a 20-minute call, or even just a reply telling me which of my assumptions is wrong? I've written a short technical brief with the full method, results, and limitations — happy to send it if useful.

Thank you for your time.

Jingjing Lei
Archbishop Mitty High School, Class of 2027
[phone] · [email]

---

## Variant: if you have a warm introduction

Replace the opening paragraph with:

> Dear Professor [Last Name],
>
> [Mutual contact's name] suggested I write to you. I'm a senior at Archbishop Mitty High School, and I've spent the last few months on speech recognition for dysarthric speech — [one specific sentence about their work].

Everything else stays. A warm intro buys you attention, not length.

---

## Variant: if they run a lab you'd want to work with

Add one sentence before the sign-off — but only if it's true:

> I'm not asking for a position. I'm asking whether the direction is sound before I spend another three months on it.

That sentence works because it's an unusual thing to say. Don't use it as a Trojan horse for asking for a position; people can tell.

---

## Follow-up (send once, 10 days later, reply to your own thread)

> Dear Professor [Last Name],
>
> Following up briefly on the note below. Since writing, I've [one concrete thing that changed — a run you completed, a number that moved, an organization that responded].
>
> Still would value your read, even a one-line one. And if this isn't your area or your time is spoken for, no reply needed — I won't write again.
>
> Jingjing

Then stop. One follow-up. The willingness to say "I won't write again" is what makes it land, and it only works if you mean it.

---

## What to do with a reply

If they answer a technical question, **run the experiment they suggest and report back within two weeks.** That single loop — ask, act, return with data — is what converts a cold email into an actual relationship. Most people never close it, which is exactly why closing it works.
