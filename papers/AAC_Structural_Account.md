# The Device Is Not the Problem

## Structural causes of augmentative communication abandonment, and the case for moving support to the listener

Jingyu Lei
Archbishop Mitty High School
September 2026

---

## Abstract

Augmentative and alternative communication (AAC) has improved substantially over four decades, from letterboards to eye-gaze tablets to language-model-assisted prediction. The proportion of AAC systems still in use one year after introduction has not improved with it. The best available estimate, from a 2006 survey of AAC specialists, is 39 percent. This paper argues that the persistence of that figure across successive generations of technology is the central finding: a constraint that survives improvement in the thing supposedly constrained is not located in that thing.

I identify five structural layers, each with an independent evidence base, and argue that they compound into a feedback loop. First, a rate asymmetry: aided communication proceeds at roughly a tenth the rate of speech, and there is an information-theoretic reason speaker-side rate enhancement has a low ceiling. Second, a delivery chain in which every actor's role ends at handoff, no actor's role includes the adjustment that abandonment research identifies as the primary factor, and the chain filters by race and class. Third, a reimbursement architecture that classifies speech as durable medical equipment, with consequences demonstrated by the 2014 Medicare rule changes. Fourth, a funding model that treats communication as a property of one person when it is a property of two. Fifth, a social layer in which a device makes disability visible and is refused by families who fear it will prevent the speech it supplements — a fear the evidence does not support but the logic of rehabilitation does.

The model generates a prediction. An approach that removes the device, the chain, and the configuration, and that moves the rate bottleneck from the speaker's selection to the listener's reading, should exhibit a different failure profile. I describe such an approach, present evidence that it is technically feasible at near-zero cost, and state what it does not address. The adoption prediction is testable and untested.

---

## 1. Introduction

Johnson, Inglebret, Jones and Ray (2006) surveyed 275 members of the American Speech-Language-Hearing Association's special interest division on AAC and asked what proportion of the systems those clinicians had introduced were still in use more than a year later. The mean response was 39.35 percent.

By 2006, dedicated speech-generating devices had been commercially available for two decades and Medicare had covered them for five years. Touch-screen tablets arrived four years later, followed by eye-gaze tracking, cloud-synchronized vocabularies, and, most recently, language models that predict what a user will say. Each was presented as the development that would close the gap. There is no evidence that any of them moved the retention figure substantially. The field does not systematically measure whether delivered devices are in use a year later; what data exist come from clinician recall and small cohorts, and they continue to fall in the same range.

This paper takes that persistence as its starting point. If better devices did not produce better retention, the reason people stop using AAC is not primarily that the AAC was inadequate.

The claim is bounded. Phillips and Zhao (1993) found poor device performance to be one of four significant predictors of abandonment across assistive technology generally, and it would be surprising if device quality were irrelevant. The claim is that device quality is one factor among several, that the others are structural rather than technical, and that the field's focus on the device has left the structural factors under-examined and largely unaddressed.

The paper has three parts. Sections 2 through 6 each take one structural layer. Sections 7 and 8 address a conflict internal to the field about attributed competence and a recent argument that abandonment is mis-named. Section 9 formalizes the layers as a causal model and states its predictions. Sections 10 and 11 describe an approach designed around those predictions, present evidence of its technical feasibility, and state its limits.

---

## 2. The rate asymmetry

### 2.1 The gap

Conversational speech runs at roughly 125 to 185 words per minute. Users of aided AAC produce between 12 and 18, and many produce fewer. Recent work using language models fine-tuned on AAC corpora to predict upcoming words reaches the mid-twenties. Aided communication proceeds at roughly a tenth the rate of speech.

### 2.2 Why speaker-side enhancement has a ceiling

The gap is not a limitation of any particular device. It follows from the input channel. A person selecting symbols or letters with a finger, a switch, or an eye-gaze cursor performs a serial motor task where a speaker performs a parallel one, and the information rate of the serial task is bounded.

The bound can be estimated. Cross-linguistic measurement of spoken information rate finds that speech in unrelated languages converges on roughly 39 bits per second (Coupé et al., 2019). A selection from a grid of 60 symbols carries at most about 6 bits, and a proficient user makes perhaps one selection per second. Word prediction raises the information per selection, but the selection rate itself is bounded by motor speed, and for users with motor impairment — the majority of AAC users — that bound is low and does not improve with practice past a plateau. The best reported rates with language-model prediction sit in the mid-twenties of words per minute, which is consistent with a channel capacity roughly an order of magnitude below speech. Forty years of rate-enhancement research has produced gains of tens of percent against a deficit of a factor of ten, and the shape of that record is what one would expect from a channel near its capacity.

### 2.3 What the clock does

Conversation has a turn-taking system whose tolerances are measured in fractions of a second, and cross-linguistic evidence indicates that this holds across unrelated languages and cultures (Stivers et al., 2009). At twelve words per minute a ten-word sentence takes fifty seconds. The AAC user is two orders of magnitude outside the norm.

The partner's response to this is not a failure of goodwill; it is what the norm does to people who hold it. The partner experiences the silence as a breach and fills it. Light, Collier and Parnes (1985) documented the resulting pattern: communication partners of AAC users take the majority of turns, provide few opportunities for the AAC user to initiate, and ask a disproportionate number of yes/no questions. The yes/no question is the partner's adaptation to the clock. It converts a fifty-second answer into a one-second one by performing the sentence construction on the user's behalf and leaving the user the confirmation. The AAC user's contribution is reduced to assent, and the reduction is invisible to everyone present, because it looks like accommodation.

There is a further effect. When device output lags the flow of conversation, partners rate the AAC user as less capable and less engaged. Slowness is read as impairment. The partner's next accommodation is to speak for the user entirely, and the user's rational response is to stop bringing the device.

### 2.4 Why this layer is different

Reimbursement can be reformed, clinicians trained, stigma reduced. The clock cannot be changed. Every other layer in this account operates on top of an interaction already tilted, by its structure, against the person the device serves. An honest account of AAC failure has to begin there.

It also has to notice something the field has not. The asymmetry has two sides. Speaker-side output is bounded near 25 words per minute. Listener-side intake is not: adults read at 200 to 300 words per minute, and the listener's reading rate is not impaired by the speaker's disability. Forty years of design effort have gone into the side of the conversation that has no capacity. Section 10 returns to this.

---

## 3. The delivery chain

### 3.1 The structure

An AAC device is delivered at the end of a chain. In the United States the typical sequence is: a speech-language pathologist evaluates and recommends; a physician prescribes; a funder — Medicaid, Medicare, or private insurance — approves or denies; a vendor supplies; the SLP or vendor configures and provides initial training; the person goes home.

### 3.2 The first link

A 2024 scoping review of thirteen studies on SLP confidence and competence in AAC found that approximately 40 percent of graduating SLP students did not feel prepared to work with AAC users and 52 percent were not confident in their ability to assess or treat them. Confidence among practising clinicians varied by task and by client population. An Australian study of practising SLPs took its title from a participant's description of her colleagues: they absolutely love it, or they are terrified of it. The people at the front of the chain are, by their own account, often uncertain of what they are doing.

### 3.3 The filter

The chain does not admit everyone. Among families of minimally verbal children with autism, 84 percent of white families had access to an AAC device; 32 percent of families from racial and ethnic minorities did. More than half of minority families reported not knowing what an AAC device is. A secondary analysis of intervention records found that Black preschool students received significantly less AAC intervention per week than white peers, with three-quarters receiving under sixty minutes weekly — an amount the authors characterized as inadequate for meaningful gains given the severity of the children's disabilities. Rural families are less likely to reach speech-language services at all.

These are not failures at the device. They are failures of the chain to reach the person. A structure that requires an evaluation, a prescription, an approval, and a vendor relationship is a structure that requires a family with the time, the insurance, the geography, and the vocabulary to navigate four institutions. The abandonment literature counts only those who got a device. It does not count those who never reached the first gate, and the disparity data suggest that population is large and non-random.

### 3.4 The missing role

Every actor in the chain has a role that ends at handoff. The SLP's evaluation is complete when the recommendation is written; the physician's when the prescription is signed; the funder's when the claim is paid; the vendor's when the device ships. The chain is a sequence of completions, and the last handoff is to the family.

Johnson et al.'s factor analysis found that the construct most associated with abandonment was *not maintaining or adjusting the system*. Phillips and Zhao found that *change in user needs or priorities* was a significant predictor, and that abandonment peaked in the first year and again after five — the points at which a person's needs have moved furthest from the configuration they were given. The device correct at fitting is incorrect six months later, and the chain has no actor whose role is to notice.

This follows from what a prescription-and-delivery model is for. It is a model for objects that do not change once delivered: a wheelchair, a hearing aid, a brace. It fits poorly a system whose value depends on continuous adjustment to a changing person, and the poor fit appears exactly where the abandonment data locate it.

### 3.5 Procurement and investment

Phillips and Zhao's four predictors include one that runs against intuition: *easy device procurement* predicted abandonment. Devices simple to obtain were more likely to be dropped. The interpretation the authors offer is that the process of selection is part of adoption. A person who has worked to choose a device has invested in it, understands it, and has had their preferences reflected in it. A person handed a device has none of that. The predictor listed first in their analysis was *lack of consideration of user opinion in selection*.

The problem with the chain, then, is not that it has gates. It is that the person for whom the device is intended stands at none of them. The evaluation is conducted on them; the prescription written for them; the funding approved on their behalf; the device configured for them. The structure does not require their preference to be sought at any point, and Phillips and Zhao's data indicate that this omission predicts abandonment more strongly than any feature of the device.

---

## 4. Speech as durable medical equipment

### 4.1 The category

Since January 2001, under National Coverage Determination 50.1, Medicare has covered speech-generating devices as durable medical equipment. DME is a benefit category defined by the Social Security Act and built around wheelchairs, hospital beds, and oxygen equipment: objects prescribed, delivered, and used unchanged until they wear out. Coverage under DME made SGDs accessible to a large population and was correctly regarded as a victory. Its price was that a person's means of communication would be governed by rules written for their means of mobility.

### 4.2 2014

The consequences were latent for thirteen years. In February 2014, Medicare's contractors announced that effective April 1, SGDs would no longer be purchased but rented under capped-rental rules. The regulatory basis was a provision classifying equipment as routinely purchased only if it had been purchased at least 75 percent of the time during a reference period. The reference period was 1986 to 1987. Speech-generating devices did not exist in 1986. Medicare's own claims data for 2012 showed them purchased 99.3 percent of the time. The Center for Medicare Advocacy noted that the argument that the devices could not have been routinely purchased in a period predating their invention "has not impressed CMS."

Capped rental has a specific consequence for a person who enters a hospital, nursing facility, or hospice during the thirteen-month rental period. Under Part A the facility's per-diem payment is deemed to include medically necessary equipment, and the rented device does not accompany the patient. A person with amyotrophic lateral sclerosis who communicated through an eye-gaze device configured over months to their remaining abilities would, on admission to hospice, be expected to use whatever generic device the facility could supply. For most such patients that meant no device.

A second change, announced for September 1, 2014, withdrew coverage from any device capable of a function beyond speech — email, for instance — although users had always paid privately for such functions and Medicare had never funded them. This reversed the explicit language of the 2001 determination, which contemplated software allowing a laptop or handheld computer to function as an SGD. The Center for Medicare Advocacy's reading of the motive was that the agency did not want the public to think Medicare was paying for tablets, laptops, or phones.

Both changes were reversed by the Steve Gleason Act of 2015, later made permanent, after a campaign led by the former professional football player of that name, who has ALS and communicates through an eye-gaze device. The reversal was correct. The episode should be read for what it reveals. An agency applied a rule from a reference period predating the technology, with the effect of removing people's means of communication at the moment of greatest vulnerability, and was moved not by the internal logic of its own coverage determination but by the public visibility of a well-known patient. The category held; the exception was carved for the cases the public could see.

### 4.3 The ongoing effect

Under the DME model, Medicare pays for a dedicated device and, since a later clarification, for speech-generating software installed on a general computing device, but not for the general computing device itself. A person who already carries a phone cannot have the phone's capacity to speak for them funded, because the phone is not medical equipment. They are issued a separate object, which is medical equipment, and which announces itself as such. The prescription requires a physician's signature, and the physician typically has no training in AAC; the signature certifies medical necessity, which is the category's requirement, not communicative benefit, which is the person's need.

### 4.4 What the category error is

It is easy to read 2014 as bureaucratic malfunction and miss the conception underneath. Durable medical equipment replaces or supports a bodily function. A wheelchair does what legs do. The DME model asks a speech-generating device to do what speech does, and the request contains a mistake about what speech is. Speech is not a bodily function in the way locomotion is. It is a social act whose value is realized entirely in another person's understanding. A wheelchair that moves a person succeeds regardless of who is watching. A speech device that produces a sentence no one waits to hear has done nothing. The DME category can pay for the device. It cannot represent, let alone pay for, the conditions under which the device does what it is for.

The motive the Center for Medicare Advocacy attributed to the 2014 changes — avoiding the perception of paying for technology rather than health care — is evidence that the category is ideological as well as administrative. Speech support that looks like a medical device is fundable. Speech support that looks like a phone is not, regardless of function. That distinction is not about cost or efficacy. It is about what kind of thing the public is understood to accept Medicare paying for.

---

## 5. The half of the dyad that is not funded

### 5.1 The finding

Communication is a property of at least two people. The funding, assessment, and training architecture of AAC is built around one.

Light's work in the 1980s established that AAC interactions are dominated by the non-AAC partner. The subsequent decades produced a literature on communication partner instruction, and by 2015 Kent-Walsh and colleagues could conduct a meta-analysis. The instruction works. Partners taught to use expectant delay — waiting, visibly, for the AAC user to respond — to model aided language on the device themselves, to ask open rather than closed questions, and to provide opportunities to initiate produce interactions in which the AAC user communicates more, and the effect sizes are large.

### 5.2 Why it is not funded

Essentially every dollar in the AAC system attaches to the AAC user. The evaluation assesses the user; the device is prescribed to the user; training is delivered to the user. The reason is structural. Reimbursement in the American system requires a patient, a diagnosis, and a service medically necessary for that patient. The communication partner has no diagnosis. Instruction delivered to the partner is not a service to a patient. Some clinicians deliver it anyway, folded into the user's treatment session, but there is no funded role whose purpose is to change the behavior of the teacher, the aide, the sibling, or the grandparent — the people who, as Section 2 argued, are structurally induced by the clock to take the conversation over.

### 5.3 The consequence

The system equips one half of a dyad and measures success by the behavior of the other half. If the partner does not wait, the device is unused. If the partner asks only yes/no questions, the vocabulary is never exercised. If the partner speaks for the user, the device is redundant. When the device is found in a drawer a year later, the finding is recorded as abandonment by the user — placing the failure with the one person in the interaction whose behavior the system made no attempt to influence.

Johnson et al.'s constructs corroborate this. Among those associated with abandonment were *attitude*, described in terms of the people around the user, and *lack of training*, which the surveyed clinicians understood to include partners. Among those associated with success, *support* appeared first. The clinicians know the outcome depends on the room. The system they work within cannot act on it.

---

## 6. Visibility, stigma, and the fear of dependence

### 6.1 Visibility

Parette and Scherer (2004) set out the ways assistive technology is entangled with stigma, and three of their observations bear directly on adoption: visibility in public settings, device aesthetics and age-appropriateness, and the perception among families that a child who becomes reliant on a device will not develop the skills the device stands in for.

Goffman's (1963) distinction applies precisely. The *discredited* have a visible stigmatizing attribute; the *discreditable* have one known to themselves but not displayed. A person with impaired speech who says nothing is discreditable. The moment they produce a speech-generating device they are discredited. The device does not merely assist the impairment; it announces it, to everyone in range, before a word is produced.

This creates an incentive the adoption literature rarely states. A person who can manage a short exchange without the device has reason to try, because the device's cost is paid immediately and in public while its benefit arrives slowly and in private. The rational strategy in many settings is to pass. A device used only where passing is impossible is a device not used very much.

### 6.2 The dependence fear

Parette and Scherer report families declining or limiting AAC because they believe reliance on it will prevent natural speech. The evidence does not support the belief. Millar, Light and Schlosser's (2006) review of 23 studies covering 67 individuals found speech production increased in 89 percent of subjects, was unchanged in 11 percent, and decreased in none. AAC does not impede speech and modestly promotes it.

The fear persists anyway, and it should be taken seriously rather than corrected. It has a logic, and the logic is not foolish. It is the logic of rehabilitation, in which impaired function is recovered through forced practice and compensation is the enemy of recovery. That logic is correct in the domains where it applies and is the operating principle of some of the most effective pediatric therapies in existence. Constraint-induced movement therapy restores the use of a child's impaired arm by preventing use of the other one. A parent who has watched that work has been given a strong reason to believe that a device which speaks for their child will prevent the child from learning to speak.

The field's answer — that the evidence does not support the fear in the case of speech — is correct and insufficient. The fear is not primarily an empirical belief. It is an expression of what the parent wants for the child, which is to speak, and the device is a visible daily concession that the child may not. Families who refuse AAC are not, for the most part, making an error about the developmental literature. They are refusing to concede. An account that treats this as a knowledge deficit has misidentified what is being protected.

---

## 7. The competence question

There is a conflict inside the field that bears on everything above. It concerns how much to presume of a person who cannot speak.

Donnellan (1984) proposed the criterion of the least dangerous assumption: in the absence of conclusive data, decisions about a person should rest on the assumption which, if wrong, would do the least harm to their prospects. Applied to communication, it says that if it is uncertain whether a non-speaking person understands and has something to say, one should assume they do, because the cost of being wrong in that direction is wasted effort and the cost of being wrong in the other is a silenced person.

The criterion is sound and broadly accepted. What complicated its application was a term that grew from it. "Presumed competence" was introduced by Biklen (1990) in the context of facilitated communication, a technique in which a facilitator supports a non-speaking person's hand as they type. Controlled studies subsequently showed the output was authored by the facilitator, and the technique is regarded by the mainstream of the field as discredited (Wheeler et al., 1993). The term survived and carries the association.

The result is a field with a good reason to be careful about over-attributing capability, because over-attribution once produced a scandal in which people were spoken for under the guise of being helped, and a good reason to be careful about under-attributing it, because under-attribution is the older and more common failure. Clinicians writing in 2018 argued that selecting a system on the basis of presumed competence rather than clinical assessment and functional trial is not the least dangerous assumption but a dangerous one. They are not wrong. Neither are advocates who observe that the assessment they recommend is conducted by professionals who, per Section 3, report low confidence in conducting it.

The mechanism by which this produces non-adoption is specific. A device is prescribed. The person uses it at twelve words per minute in a room where the partner fills the silence. The output is short, slow, and often limited to confirmation. That output is then read, by partner and sometimes clinician, as a measure of the person's capacity. The device meant to reveal what the person could say is taken as evidence of what they cannot. Lower estimated capacity produces lower expectations, simpler vocabulary, more yes/no questions, and a device adjusted downward or not at all. The device is abandoned, and the abandonment is read as confirmation.

---

## 8. Is abandonment the wrong word?

Smidt and Pebdani (2023) argue that it is. Applying Sen's capability approach to AAC, they propose that what the literature calls abandonment is often a person and their family choosing to use the full range of multimodal communication available to them — gesture, vocalization, partner familiarity, a low-tech board — to meet their own needs, and that the framing of abandonment casts a competent agent exercising self-determination as a patient who failed to comply.

The argument is right about the framing and should be absorbed. A person who sets aside a device because gesture and a familiar partner serve them better has not failed. But the capability approach, taken seriously, strengthens rather than weakens the structural account. Sen's capability is real freedom to achieve valued functionings. If the device delivers no real freedom — because the partner does not wait, the vocabulary was never adjusted, the object marks its user, and every setting in which it might help is a setting in which the clock runs against them — then non-use is a rational response to a structure that made the device a poor option. The question the capability approach directs us to is not whether the person chose. It is why the device offered so little to choose.

---

## 9. The model

### 9.1 The loop

The layers form a feedback system. Stated as a sequence: the rate asymmetry induces partner takeover; takeover reduces the user's output to confirmation; reduced output is read as reduced capacity; reduced capacity lowers expectations and the demands placed on the device; the device is never adjusted, because no actor in the chain has adjustment as a role and no funding follows the device past delivery; the unadjusted device fits the person less well over time; it is also visible, marks them, and confirms the family's fear of concession; it is used less, then only where passing is impossible; a year later it is in a drawer and the drawer is recorded as the user's decision.

At no point in that sequence did the device fail. At every point a structure built around the device — and around a conception of communication as an individual medical function restored by equipment — failed to do what the device's success required.

### 9.2 The edges

The table below states each causal edge in the model, its direction, and how well the literature supports it.

| Edge | Direction | Evidence |
|---|---|---|
| Rate asymmetry → partner takes turns, asks yes/no | + | Established (Light et al., 1985) |
| Slow output → partner rates user as less capable | + | Reported; needs a specific citation |
| Lower attributed capacity → simpler vocabulary, fewer opportunities | + | Suggested (Section 7 mechanism); not directly measured |
| No adjustment role in chain → device unadjusted over time | + | Established as association (Johnson et al., 2006 factor 1); causal direction inferred |
| Unadjusted device → abandonment | + | Established (Johnson et al., 2006; Phillips & Zhao, 1993) |
| Visibility → nonuse in public | + | Established qualitatively (Parette & Scherer, 2004); not quantified |
| Dependence fear → family limits use | + | Established qualitatively (Parette & Scherer, 2004) |
| User not involved in selection → abandonment | + | Established (Phillips & Zhao, 1993 predictor 1) |
| Chain requirements → unequal access by race and class | + | Established (disparity studies, Section 3.3) |
| Partner instruction → user communicates more | + | Established (Kent-Walsh et al., 2015 meta-analysis) |
| Partner instruction → funded | 0 | No mechanism; structural inference |

Four of Johnson et al.'s five abandonment constructs — not adjusting, attitude, lack of training, lack of support — describe the structure around the device rather than the device. The fifth, poor fit, is the only one that describes the object, and it is partly a consequence of the first.

### 9.3 What the model predicts

The model makes a prediction that distinguishes it from a device-centered account. If the loop is what holds the retention figure where it is, then improving the device without changing the structure should produce small effects, which matches the field's history. And an approach that removes several layers at once — not the device's quality but the device itself, the chain, the configuration, the visibility — should exhibit a different failure profile, with residual failure concentrated in the layers the approach does not touch.

That prediction is testable. Section 10 describes an approach designed to test it.

---

## 10. Moving support to the listener

### 10.1 The design

Every AAC approach for forty years has operated on the speaker's side of the asymmetry, and Section 2 argued that side is near its capacity. The listener's side is not. A listener reads at 200 to 300 words per minute, and that rate is unaffected by the speaker's disability.

Consider an approach with the following properties. The speaker speaks naturally, with whatever impairment they have. Software on the speaker's own phone transcribes the speech using a recognizer adapted to impaired speech. The transcript appears on the speaker's screen, for the speaker, who reads it, corrects it if needed, and decides whether to show it to the listener — as large text, or read aloud by the phone. Nothing leaves the phone. There is no account, no server, and nothing to configure.

Measured against the model, this design removes or alters the following:

- **The rate bottleneck moves.** The speaker produces at speaking rate, even dysarthric speaking rate, which is far above twelve words per minute. The listener consumes at reading rate. The interaction is bounded by the side with capacity.
- **There is no device.** Nothing is prescribed, delivered, or classified as DME. The phone is the person's own. Section 4 does not apply.
- **There is no chain.** No evaluation, prescription, approval, or vendor. The filter in Section 3.3 has nothing to filter through. This is not unambiguously good: it also means no clinician is involved, which Section 11 returns to.
- **There is nothing to adjust.** No vocabulary, no layout, no settings tied to the person. Johnson et al.'s primary abandonment factor has no object to act on. The recognizer improves when its maintainer updates it, not when the family does.
- **There is no visible device.** A phone on a table does not discredit its user in Goffman's sense. Section 6.1 is weakened, though not eliminated, since showing a transcript is itself a disclosure.
- **The speaker controls disclosure.** The transcript is private until the speaker shows it. This addresses, structurally, the mechanism in Section 7 by which slow public output is read as low capacity: the output is not public until the speaker has reviewed it.

What the design does not touch is the partner. The partner is still induced by the clock and by every other feature of the situation to take over. A transcript the speaker shows can be ignored, or read and then followed by a yes/no question. Section 5 is unaddressed, and the model predicts that residual failure will concentrate there.

### 10.2 Is it feasible?

The design depends on a recognizer that works on impaired speech. Off-the-shelf recognition does not. On the TORGO corpus — speakers with dysarthria and control speakers reading identical prompts through identical microphones in the same room — `whisper-small` produces a sentence word error rate of 2.9 percent for control speakers and 48.0 percent for dysarthric speakers, a sixteen-fold gap with the acoustic environment held constant. Error rises monotonically with clinician-rated severity: 12.7 percent for mild, 29.5 percent for moderate, 77.8 percent for severe.

The gap can be substantially closed at low cost. A low-rank adaptation of 3.5 million of the model's 245 million parameters — 1.44 percent — trained on 152 minutes of speech from eight dysarthric speakers, on a laptop CPU, in 2.5 hours, at no monetary cost, reduces sentence word error on held-out utterances from the most severely affected speaker from 84.4 percent to 34.6 percent. Single-word accuracy rises from 8.1 to 67.6 percent. Thirty-seven of fifty-nine held-out clips improve.

One result bears directly on the model. Adaptation on the pooled data of eight speakers outperforms adaptation on the target speaker's own 24 minutes — 34.6 percent versus 50.8 percent word error. If that holds under leave-one-speaker-out evaluation, which has not yet been run, it means a shared recognizer can serve a new person without enrollment. Enrollment is the point at which a listener-side tool would otherwise reintroduce the selection process that Phillips and Zhao identify as the primary predictor of abandonment. A tool that works on first use has no such step.

### 10.3 What this does and does not show

These results demonstrate technical feasibility. They do not demonstrate adoption. No person with a speech impairment has used the system; all results are on a research corpus of read speech under laboratory conditions; the corpus contains eight dysarthric speakers, all adults with cerebral palsy or ALS; and the headline number is from one severe speaker whose data was included in the pooled training set. A recognizer that is wrong on a third of words in a sentence is better, not solved.

The adoption prediction — that this design will show a different failure profile from device-based AAC, with residual failure concentrated at the partner — is the claim this paper makes and has not tested. Testing it requires putting the tool in front of people and measuring communication outcomes over time, which is the measurement Section 11 argues the field lacks.

---

## 11. Implications

Three things follow from the account, and none is a better device.

**Measure communication, not delivery.** The abandonment literature is thin because the field measures what each actor delivers — the evaluation, the claim, the shipment, the laboratory accuracy — and no actor measures whether the person was understood by someone who mattered to them, in a place that mattered, a year later. Until that measurement exists the loop in Section 9 will remain invisible, because no one stands where it can be seen. A minimal outcome measure — utterances produced, distinct partners, settings, and corrections, collected over months — is not technically difficult and would answer questions the field has been unable to ask.

**Fund the partner.** The evidence that partner instruction works is among the strongest in the field, and the absence of any mechanism to pay for it is among the field's clearest structural failures. This is a policy change, not a research finding, and it is achievable. It is also the one intervention the listener-side design cannot substitute for, which makes it the most important thing to fund if that design is adopted.

**Treat the DME category as a historical accommodation.** It bought coverage in 2001 at the cost of filing speech under equipment, and the bill came due in 2014 and continues to come due each time a person is issued a dedicated device to carry alongside the phone they own. A model in which communication support is a capability of ordinary devices, funded as a service, would remove the visibility cost, the dependence signal, and the maintenance gap in one move. It would also require Medicare to pay for something that looks like technology rather than health care, which is the perception the 2014 changes were designed to avoid.

The listener-side design also introduces a risk the model does not predict, and it should be named. A tool that makes a person easier to understand without changing how they speak is, in the rehabilitation logic of Section 6.2, a compensation. Whether that fear is warranted for speech transcription — as it is not for AAC — is unknown. The forced-use principle that underlies constraint-induced therapy has a mechanism, and that mechanism may or may not apply to a tool that leaves the speaker's own speech in place and only changes what the listener receives. That is a question for clinicians in neurorehabilitation, and it is the question I would most want answered before recommending the design to a family.

---

## 12. Limitations

This paper reports no new abandonment data. Its claims about retention rest on a literature that is thin, largely American, based on clinician self-report, and mostly cross-sectional. The 39.35 percent figure may be wrong in either direction; the argument depends not on its precise value but on the absence of evidence that it has improved, which is a weaker claim.

The institutional sections are United States-centric. Other systems classify communication support differently and may fail differently.

The causal model in Section 9 is a model. It fits the available evidence and makes a prediction. Several of its edges are inferred rather than measured, and the table marks which. The prediction has not been tested.

The empirical results in Section 10 are corpus results from eight adult speakers. The pooled-beats-personal finding has not been evaluated leave-one-speaker-out. No human has used the system. The results establish that a listener-side recognizer for impaired speech can be built cheaply; they establish nothing about whether it will be used.

---

## References

Biklen, D. (1990). Communication unbound: Autism and praxis. *Harvard Educational Review*, 60(3), 291–314.

Center for Medicare Advocacy. (2014, June 5). *Medicare's reluctance to embrace technology: Effects on the coverage of speech generating devices.*

Coupé, C., Oh, Y. M., Dediu, D., & Pellegrino, F. (2019). Different languages, similar encoding efficiency: Comparable information rates across the human communicative niche. *Science Advances*, 5(9), eaaw2594.

Donnellan, A. M. (1984). The criterion of the least dangerous assumption. *Behavioral Disorders*, 9(2), 141–150.

Goffman, E. (1963). *Stigma: Notes on the management of spoiled identity.* Prentice-Hall.

Johnson, J. M., Inglebret, E., Jones, C., & Ray, J. (2006). Perspectives of speech language pathologists regarding success versus abandonment of AAC. *Augmentative and Alternative Communication*, 22(2), 85–99.

Kent-Walsh, J., & McNaughton, D. (2005). Communication partner instruction in AAC: Present practices and future directions. *Augmentative and Alternative Communication*, 21(3), 195–204.

Kent-Walsh, J., Murza, K. A., Malani, M. D., & Binger, C. (2015). Effects of communication partner instruction on the communication of individuals using AAC: A meta-analysis. *Augmentative and Alternative Communication*, 31(4), 271–284.

Light, J., Collier, B., & Parnes, P. (1985). Communicative interaction between young nonspeaking physically disabled children and their primary caregivers: Part I — Discourse patterns. *Augmentative and Alternative Communication*, 1(2), 74–83.

Millar, D. C., Light, J. C., & Schlosser, R. W. (2006). The impact of augmentative and alternative communication intervention on the speech production of individuals with developmental disabilities: A research review. *Journal of Speech, Language, and Hearing Research*, 49(2), 248–264.

Parette, P., & Scherer, M. (2004). Assistive technology use and stigma. *Education and Training in Developmental Disabilities*, 39(3), 217–226.

Phillips, B., & Zhao, H. (1993). Predictors of assistive technology abandonment. *Assistive Technology*, 5(1), 36–45.

Pope, L., Light, J., & Franklin, A. (2022). Black children with developmental disabilities receive less augmentative and alternative communication intervention than their white peers: Preliminary evidence of racial disparities from a secondary data analysis. *American Journal of Speech-Language Pathology*, 31(5), 2159–2174.

Rudzicz, F., Namasivayam, A. K., & Wolff, T. (2012). The TORGO database of acoustic and articulatory speech from speakers with dysarthria. *Language Resources and Evaluation*, 46(4), 523–541.

Smidt, A., & Pebdani, R. N. (2023). Rethinking device abandonment: A capability approach focused model. *Augmentative and Alternative Communication*, 39(3), 198–206.

Stivers, T., Enfield, N. J., Brown, P., Englert, C., Hayashi, M., Heinemann, T., Hoymann, G., Rossano, F., de Ruiter, J. P., Yoon, K.-E., & Levinson, S. C. (2009). Universals and cultural variation in turn-taking in conversation. *Proceedings of the National Academy of Sciences*, 106(26), 10587–10592.

Wheeler, D. L., Jacobson, J. W., Paglieri, R. A., & Schwartz, A. A. (1993). An experimental assessment of facilitated communication. *Mental Retardation*, 31(1), 49–60.

*The confidence and competence of speech language pathologists in augmentative and alternative communication: A scoping review.* (2024). *Augmentative and Alternative Communication.* https://doi.org/10.1080/07434618.2024.2333383
