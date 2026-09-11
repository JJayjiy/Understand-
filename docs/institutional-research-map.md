# The Institutional Arm — where the real barrier is

**Premise (your own result):** speech clarification for severe dysarthria now costs 24 minutes of audio and $0 of compute, and cuts word error 6.7×. The technical barrier has fallen.

**Question:** so what actually stands between this and the people who need it?

No IRB required for any of this. It's document research — published policy, coverage criteria, procurement rules. You can start today.

---

## First, the impact reframe

If the barrier is institutional, a better model helps nobody. That inverts the usual student-project instinct — the highest-impact move may not be more training runs.

Three things that would create real, durable impact, roughly in order:

1. **Release what you have, free and open.** Publish the fine-tuning recipe and adapters so any SLP, family, or developer can adapt a model with 24 minutes of audio. That outlives every deadline on your calendar.
2. **Document the barriers precisely**, so the next person doesn't rediscover them.
3. **Design around whichever barrier you find.** Your findings should change the product, not just describe the world.

---

## Finding #1 — the device/software distinction (biggest one)

This is already reshaping your architecture decision, and you didn't know it existed.

**Medicare does not cover tablets, smartphones, or computers as durable medical equipment** — explicitly, even when they serve a medical purpose. But it **does** reimburse speech-generating *software* on a general computing device under **HCPCS E2511**.

Dedicated speech-generating devices are covered under **E2500–E2510**, graded by recording time and message type.

**What this means for CoHear:**

- Your phone app could plausibly be reimbursable as software (E2511) — but the phone itself never is.
- Your hero device *might* qualify as an SGD under E2500–E2510 if it meets DME criteria — durable, primarily medical purpose, not useful to someone without the condition.
- Only **one SGD per patient** is covered; additional claims are denied as not medically necessary.

That last rule is worth sitting with. If someone already has a funded AAC device, a second one — yours — will not be covered no matter how well it works. Complementing an existing device may matter more than replacing it.

**Documents to read:** CMS Policy Article A52469 (Speech Generating Devices), ASHA's Medicare SGD policy page, and one or two commercial payer policies (Cigna 0049, Humana) to see how private insurers differ.

---

## Finding #2 — the prescription gate

Before an SGD is delivered, a **speech-language pathologist must formally evaluate** the patient's cognitive and communication abilities, and a physician must prescribe it.

This reframes your SLP outreach entirely. SLPs aren't just experts to learn from — **they are the legal gatekeepers of the funding pathway.** Nothing reaches a Medicare patient without one.

**Worth investigating:** what does an SLP's AAC evaluation actually assess? If you knew the criteria, you'd know what CoHear must demonstrate to be recommendable. That's a design specification hiding in a clinical protocol.

---

## Finding #3 — the abandonment data, and why it should worry you

**29.3% of assistive devices obtained are abandoned.** Reported rates across categories run from 8% to 75%; hearing aids reach 78%.

Four factors predict abandonment. The strongest is **lack of consideration of user opinion in device selection** — the technology was chosen *for* someone rather than *with* them.

Two implications, one uncomfortable:

- Your "the speaker reviews and approves" principle isn't just ethics. It's the single strongest documented protection against abandonment. You can now cite evidence for a design choice you made on instinct.
- Abandonment peaks in the **first year** and again **after five years**. A demo proves nothing about either. Any claim of impact needs longitudinal follow-up, which almost no student project has.

**Papers to read:** Phillips & Zhao, *Predictors of Assistive Technology Abandonment*; Federici et al., *Assistive Technology Abandonment: Research Realities and Potentials*.

---

## Finding #4 — schools (a different system entirely)

IDEA requires that assistive technology be **considered in every IEP**, and districts must provide AT when it's needed for a free appropriate public education. That's a legal mandate, not a courtesy.

But between mandate and reality sit: district procurement cycles, mobile device management that blocks app installs, staff training time nobody has, and privacy rules.

**Worth investigating:** pull the AT procurement policy and student-device acceptable-use policy for one district — San Jose Unified, say. These are public documents. Find out whether a teacher could actually install your app on a school iPad, or whether it would need district IT approval, a vendor contract, and a data-privacy agreement. The answer determines whether "free" means anything in a school.

---

## Finding #5 — voice data privacy

Student voice recordings may constitute FERPA-protected educational records. Under-13 users bring COPPA. Clinical settings add HIPAA. Each imposes different storage, consent, and vendor-agreement requirements.

**This one you can turn into an advantage.** Your offline, on-device mode means recordings never leave the device — which sidesteps most of the vendor-agreement burden that stops school adoption of cloud AI tools. Most competitors can't say that.

**Worth investigating:** what does a district require before approving a cloud service that processes student voice? If the answer is "a signed data privacy agreement and a 6-month review," then on-device processing isn't a privacy nicety — it's your entire distribution strategy.

---

## What to do first

**This week, no permissions needed:**

1. Read CMS Policy Article A52469 and ASHA's Medicare SGD page. Write one page on where CoHear would and wouldn't fit.
2. Pull one district's AT and device policies. Write one page on whether your app could actually be installed.
3. Read the two abandonment papers. Note which of the four risk factors your design already addresses and which it doesn't.

**Then decide what it changes.** The point of this arm isn't a literature review — it's that the findings should visibly alter what you build. If the funding pathway favors dedicated devices, that argues for the hero device. If schools block installs but allow web apps, that argues for the browser. If abandonment tracks user agency, that argues for making review-and-approve central rather than optional.

**The strongest version of this project** is: *here is a measured technical result, here is why it still won't reach anyone, and here is what I changed because of that.* Very few people — at any level — do all three.
