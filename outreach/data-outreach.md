# Reaching out for data

Three targets, in the order to send them. Each has a different relationship to you and a different ask.

---

## 1. Dr. DeLuca — the follow-up (send first, today)

She offered two things: an introduction to a speech-language pathologist, and the possibility — hedged, because the process is long — of coordinating something with children in her group. Both are better than anything you'd have asked for. The email should make each one easy to act on and add nothing else.

**Don't ask about Hustad in this email.** She offered her own group. Don't dilute it.

**Subject:** Thank you — and two things to make easy

Hi Dr. DeLuca,

Thank you for the time on [day]. [One sentence: the specific thing she said that changed your thinking, from your notes. Not a compliment — a thing you now do differently.]

On the speech-language pathologist you mentioned — I'd be grateful for the introduction whenever it's convenient. So it costs you nothing to write, here are two lines you could forward or paste:

> *Jingyu is a high school senior who's built an on-device speech recognition tool adapted for dysarthric speech, trained on TORGO with the maintainers' approval. It runs on the speaker's own phone and they control what gets shown. She'd value a clinician's read on where it helps and where it could get in the way.* Demo: https://huggingface.co/spaces/JJaysz/cohear

On the possibility of working with children in your group: I understood you to mean the process is long, and I'd rather do it properly than quickly. If it's something worth exploring, I'd like to know what the first step actually is — an IRB protocol, a supervising researcher, a consent framework — so I can start on whatever paperwork is mine to do. And if on reflection it isn't the right fit, I'd rather know that than have you spend time on it.

I'll send a short update in a month or so unless you'd prefer I didn't.

Thank you again.

Jingyu

**Why it's built this way:**

The two-line blurb is the most important thing in the email. Introductions die because the introducer has to write something, and writing something is work. Hand her the text and the intro takes her thirty seconds. Keep it in *her* voice, not yours — that's why it's third person and short.

The children paragraph does three things at once: shows you heard "the process is long" and aren't naive about IRB and minor consent; asks for the *first step* rather than the outcome, which is a question she can answer in one line; and gives her a clean exit. Senior researchers say yes more readily when saying no is also easy.

"Whatever paperwork is mine to do" is the phrase that matters. It signals you'll carry the load, not hand it to her.

**After she replies:** if she names the first step, do it within a week and tell her. If she makes the SLP intro, reply to the SLP within a day — that's the one where speed matters, because the SLP is doing a favor for DeLuca, not for you, and a slow reply reads as ingratitude to both.

---

## 2. Speech Accessibility Project — a formal data request

This is the largest dysarthric speech corpus in existence: 500+ speakers, 400+ hours, five etiologies. Adults only, but it would let you test whether your adaptation generalizes beyond TORGO's eight speakers — which is the question every reviewer will ask.

They accept proposals from nonprofits and companies. You're neither. Ask anyway; the worst answer is no, and a released model with a maintainer's endorsement is a real credential.

**Where:** https://speechaccessibilityproject.beckman.illinois.edu — look for the data access or research proposal form. If there's a contact email, use it.

**Subject:** Data access request — evaluating an open dysarthria-adapted Whisper model

To the Speech Accessibility Project team,

I'm a high school senior who has trained and publicly released a LoRA adaptation of Whisper for dysarthric speech, using the TORGO corpus with the maintainers' approval. On the most severely affected held-out TORGO speaker, word error rate fell from 84.4% to 34.6%. The weights and a browser demo are public:

- https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric
- https://huggingface.co/spaces/JJaysz/cohear

The limitation I most need to address is generalization. TORGO has eight dysarthric speakers, all with cerebral palsy or ALS. I'd like to evaluate — and if warranted, further adapt — the model on SAP data across Parkinson's, Down syndrome, and stroke, and to run a proper leave-one-speaker-out evaluation at a scale TORGO can't support.

I understand the project primarily works with organizations. If individual researchers aren't eligible, I'd appreciate knowing whether there's a path — for instance through a sponsoring institution — and I'm happy to provide a fuller proposal, my data-handling plan, and a reference from Dr. Frank Rudzicz, who maintains TORGO and reviewed my release.

The model is released for non-commercial research use, and any work with SAP data would be under the same terms and your data use agreement.

Thank you for considering this.

Jingyu Lei
Archbishop Mitty High School, San Jose
[email]

**Before sending:** ask Frank if you can name him as a reference. One line in your existing thread: "I'm applying for Speech Accessibility Project data access — would you be comfortable being named as someone they could contact about the TORGO release?" He'll almost certainly say yes, and it's the single strongest thing in the email.

---

## 3. Dr. Katherine Hustad, UW–Madison — the pediatric data

She runs the largest longitudinal study of speech in children with CP anywhere. Both pediatric-dysarthria acoustic papers I found came from her lab. This is the data you actually want, and it is not public.

**Do not send this cold if DeLuca can introduce you.** Wait for her reply to email 1. A forwarded introduction from a peer in pediatric CP research is worth ten cold emails. If DeLuca doesn't know her or doesn't offer, send the cold version below.

**Subject:** Speech recognition for children with dysarthria — a question about data

Dear Dr. Hustad,

I'm a high school senior working on speech recognition for dysarthric speech. I've released an adapted Whisper model trained on TORGO, with the maintainers' approval, that cuts word error from 84% to 35% on the most severely affected speaker. It runs on-device on a phone, and I'm building it into an app where the speaker controls what gets shown.

The gap I can't close on my own is children. Every corpus I can access is adults. Your lab's longitudinal work on speech development in children with CP is, as far as I can find, the only body of pediatric dysarthric speech recordings that exists at the scale this would need — and your 2017 and 2018 JSLHR papers with Dr. Allison are the closest thing to a map of what pediatric dysarthria actually sounds like acoustically.

I'm not asking for data access in this email. I'm asking whether there is any form of collaboration a project like mine could eventually be part of, and what I would need to have in place — institutional affiliation, IRB, a supervising researcher — for that to be possible. If the answer is that it isn't, knowing that clearly would also help.

Demo and write-up: https://huggingface.co/spaces/JJaysz/cohear

Thank you for your time.

Jingyu Lei
Archbishop Mitty High School

**Why it's shaped this way:** she is a senior researcher who will get many requests for her data and say no to most. This email doesn't ask for data. It asks what the path looks like and offers her an easy way to say "there isn't one." That is far more likely to get a real answer than a request — and if there is a path, she'll describe it.

---

## Sequencing

1. **Today:** DeLuca follow-up. Ask Frank about being a reference.
2. **This week:** SAP request, once Frank replies.
3. **When the SLP intro lands:** reply within 24 hours. Ask for twenty minutes. Bring the same two questions you'd have asked DeLuca — where does this help, where does it get in the way — plus one clinical one: *when a child sees a wrong transcript of their own speech, what happens?*
4. **Hustad:** park it. DeLuca offered her own group; that's the path. Only revisit Hustad if the DeLuca path closes.

## On the timeline

She said the process is long. She's right, and it matters to be honest with yourself about what that means. IRB approval for a study involving minors, with audio recording, at a university clinic, is typically **three to six months** from first draft to approval — and that's after there's a supervising researcher willing to be PI. Nothing with real children in her group is going to happen before your college deadlines.

That's fine. It isn't what this relationship is for. The version of this that matters is the one where, a year from now, a clinic is collecting pediatric dysarthric speech under a real protocol and your model is part of it. Nobody else is doing that. The deadlines are a reason to keep the app and the paper moving on their own track — not a reason to rush a clinician who just offered you something rare.

## What not to do

Don't send all three at once. Don't mention the app store, competitions, or college in any of them. Don't ask Hustad for data in the first email. Don't tell SAP you're a nonprofit.
