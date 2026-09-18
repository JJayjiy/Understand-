# From review to contribution — directions

The first draft synthesized. A contribution adds something that wasn't there. Here is what you have that nobody else does, and the directions that follow from it.

## What you have

1. **A controlled measurement of the ASR gap.** 2.9% vs 48.0% WER, same prompts, same room, same microphones. The number exists elsewhere in pieces; the controlled comparison is yours.
2. **Evidence that closing the gap is nearly free.** 1.44% of parameters, laptop CPU, 2.5 hours, $0. That changes the economics of the problem.
3. **The pooled-beats-personal result.** Eight speakers' data outperformed the target speaker's own. This bears directly on the abandonment literature, because it means a tool can work without enrollment — and enrollment is where the "user not involved in selection" failure lives.
4. **The calibration finding.** 27% of apparent phonological signal is measurement floor. A methodological result.
5. **A working system that removes several structural layers at once**, by design rather than by accident: no device, no prescription, no configuration, no server.

## Five directions

### A. Invert the asymmetry — recommended

Every AAC approach for forty years has tried to speed up the speaker. Prediction, faster access methods, eye gaze. The ceiling is around 25 words per minute, and there is an information-theoretic reason it won't go much higher: each selection carries a handful of bits, and speech carries roughly forty per second.

The asymmetry has a second side nobody designs for. The listener reads at 200–300 words per minute. If the speaker speaks naturally and a machine transcribes, the interaction's bottleneck moves from the speaker's selection rate to the listener's reading rate. The problem is not solved; it is relocated to the side of the conversation that has capacity.

Nobody in the AAC literature has framed it this way, and the reason is definitional: AAC is *augmentative* — it supplements or replaces the speaker's output. A listener-side tool is not AAC under that definition. That gap in the taxonomy is the contribution.

**The paper becomes:** structural account of why device-side AAC fails → the model predicts that removing the device, the chain, and the configuration should change the failure profile → a listener-side approach removes exactly those → your results show it is technically viable at near-zero cost → what it does not address, stated plainly.

**Why this one:** it's the only direction where you have data. The others are analytical.

### B. Formalize the feedback loop

Turn §8's verbal model into a causal graph: every edge named, direction marked, evidence level assigned (established / suggested / hypothesized). Re-code Johnson's five abandonment constructs against the structural layers and show that four of five are non-device. This makes the paper rigorous without new data.

**Honest assessment:** a stronger review, still a review. Worth doing *inside* direction A as the model section.

### C. Propose and build a measurement instrument

The paper's most defensible claim is that nobody measures communication outcomes over time. You could propose what should be measured — utterances per day, distinct partners, settings, edits — and implement it as opt-in, local-only logging in the app. Small, concrete, and it produces the data the field lacks.

**Honest assessment:** real but modest. Better as a section of A than a paper on its own.

### D. The equity layer

84% of white families with minimally verbal children had an AAC device; 32% of minority families did. Over half of minority families didn't know what AAC was. Black preschoolers get significantly less AAC intervention than white peers. The delivery chain has a race and class filter, and a phone-based tool has different access properties.

**Honest assessment:** important and under-examined. You have no data on it. Belongs as a section in A, not a paper.

### E. Engage the capability-approach reframe

Smidt & Pebdani (2023) argue "abandonment" is the wrong word — the person is choosing multimodal communication. If they're right, the whole abandonment literature is mis-framed. Your structural account can absorb this: the choice is real, but it's made under conditions the structure sets, and the capability approach — real freedom to achieve — actually supports asking why the device delivers so little real freedom.

**Honest assessment:** necessary as a counterargument section. Not a paper.

## Recommendation

**A, with B, D and E folded in as sections.** The rewrite in `AAC_Structural_Account.md` does this. The structural analysis is deepened, the loop is formalized, the equity data is in, the capability counterargument is engaged, and the last third of the paper is your contribution: the inversion argument and the evidence that it's feasible.

One thing to be strict about: the empirical section demonstrates *technical feasibility*, not adoption. The adoption prediction is testable and you haven't tested it. Say so. That sentence is what separates a contribution from a pitch.
