---
title: "CoHear: where the project is, and what I need next"
author: "Nick (Jingyu) Lei · Archbishop Mitty High School · jingyulei.2016@gmail.com"
date: "September 2026"
---

## What I'm building

People with dysarthria know exactly what they want to say. The problem is the listener. Speech from Parkinson's, ALS, cerebral palsy or a stroke can come out soft, slurred, or uneven, and a stranger might catch one word in five. Phone dictation is worse. It was built on typical speech, and when it can't follow, it doesn't say so. It just writes a confident, grammatical sentence that's wrong.

CoHear is a free iPhone app that tries to close that gap. You talk, and your words show up on your screen first. You check them, fix anything that's off, and then decide whether to turn the phone around so the other person can read it, or have the phone say it out loud. Everything runs on the phone. There's no account and no server, and nothing gets uploaded.

The first version is in App Store review right now.

## How the speech model works

The recognizer is OpenAI's Whisper, the small version, which runs on an iPhone. Out of the box it does badly on dysarthric speech, because almost everything it learned from was typical speech.

To adapt it, I use a method called LoRA. Instead of retraining all 244 million numbers in the model, I freeze them and add a small set of new ones, about 3.5 million, inside the parts of the model that decide what to pay attention to. Then I play it recordings paired with the correct text. Each time it guesses wrong, only those new numbers get nudged toward the right answer. After a few thousand of those nudges, it has learned a correction for how this kind of speech differs from what it expected, while everything it already knew about English stays intact.

My training data so far is TORGO, a research dataset from the University of Toronto with recordings from eight adults with cerebral palsy or ALS. The maintainers gave me permission to publish the models I trained on it.

## What went wrong, and what I learned from it

My first result looked great. For the most severely affected speaker, the error rate dropped from 84% to 35%. Then I tested the app with a real person with dysarthria, and it got almost nothing right. It wrote things like "chase you down the chinky chair."

So I went back and checked. TORGO reuses the same list of words and sentences for everyone, and 98% of my test sentences had also appeared in training. The model had mostly memorized the list. I rebuilt the test so the model was checked on a person it had never heard, saying sentences it had never seen. The honest number was much worse. Training on the other seven speakers only moved the severe speaker from 97% to 85% sentence error. A model trained on other people's dysarthria barely helps a new person.

## What does work: learning one person's voice

Dysarthric speech is hard for strangers, but it's consistent within a person. That's why a parent can understand their kid when nobody else can. So I tested whether the model could do the same thing: learn one specific voice from a short set of that person's own recordings.

For each of four TORGO speakers, I trained a personal model on 13 to 23 minutes of their recordings. Then I tested it on two things it hadn't trained on: new recordings of phrases they had taught it, and phrases they never recorded at all.

**Phrases they never taught it** (the harder test)

| Speaker | Severity | Words right, before → after | Sentence error (median) |
|---|---|---|---|
| M04 | severe | 12% → 31% | 88% → 60% |
| M01 | severe | 14% → 53% | 54% → 22% |
| M05 | moderate | 23% → 50% | 29% → 19% |
| F03 | mild | 37% → 54% | 17% → 17% |
| **Average** | | **22% → 47%** | |

**A phrase they taught it, said again in a new recording:** words right went from 26% to 74% on average.

The part I care about most is the first table. Those are sentences the model never practiced, and it still did a lot better. It wasn't memorizing phrases. It learned how that person says sounds. The severe speakers gained the most, and they're exactly the people current tools fail.

I also checked how much recording it takes. For one speaker, accuracy on taught phrases went 39% → 45% → 55% → 75% as the recordings went from about 2 to 3 to 7 to 14 minutes, and it was still climbing. So more recordings keep helping.

## Being honest about the limits

This is four speakers, recorded in a lab with good microphones. Each number comes from one training run, and when I trained the same speaker twice with different settings the results moved by around 10 points, so none of these numbers are exact. All four speakers had cerebral palsy or ALS. None had Parkinson's, which changes speech in a different way: quieter, faster, more monotone. I don't know yet how well this carries over, and that's the main thing I need to find out.

The app also can't fix what isn't in the audio. If a word comes out as a single breath, no model will recover it. When the model isn't sure, CoHear now marks the line as uncertain instead of showing it as if it were correct.

## What's built

The version in review lets someone talk, see their words, edit them, show them in large text, or have them read aloud. It has very large buttons and text for people with limited hand control. It can dim lines that sound like another person talking. It marks lines the model was guessing on, and it lets you compare four speech models, including Apple's own dictation.

The next version adds **Teach CoHear your voice**. The app shows a phrase, you record it, listen back, and keep it or redo it. You can add your own phrases, like names and things you say every day. The recordings stay on the phone until you choose to export them. I turn them into a personal model on my computer and put it back on the phone.

## What I'm asking for

I'm looking for a few people with Parkinson's-related speech changes who'd be willing to:

1. Record about 100 short phrases, roughly 20 to 30 minutes total, split up however they want. They can do it at home on an iPhone or in person with me.
2. Use their personal version of the app and tell me honestly what works and what doesn't.
3. If they want to, stay on as early users while I keep improving it.

They'd get a free version of the app tuned to their own voice, and they keep it. Their recordings are used only to build their model. They're never shared or published, and anyone can stop at any time and have everything deleted. Everyone signs a consent form first, and a family member is welcome to help. This is a student research project, not a medical device.

If you know someone who might be a good fit, or the right person to talk to, I'd really appreciate an introduction.

Thank you for reading this.

Nick Lei
jingyulei.2016@gmail.com
Code and research notes: github.com/JJayjiy/Understand-
