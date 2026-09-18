# Pediatric dysarthria data — what exists

Short version: **almost nothing public.** That's the finding, and it changes the plan.

---

## Every dysarthric speech corpus I could find

| Corpus | Speakers | Ages | Etiology | Access | Notes |
|---|---|---|---|---|---|
| **TORGO** | 8 dysarthric + 7 control | Adults | CP, ALS | Have it | English. What you trained on. |
| **UA-Speech** | 16 dysarthric + 13 control | Adults | CP | Request from UIUC | English. Isolated words only. ~103 hours. |
| **Speech Accessibility Project** | 500+ | **18+ only** | PD, ALS, CP, Down syndrome, stroke | Data use agreement; accepting proposals from nonprofits | English. 400+ hours. The big one. Excludes Illinois, Texas, Washington residents. |
| **Project Euphonia** (Google) | ~1,000+ | Adults | Mixed | Not generally released | 1M+ utterances. Internal to Google. |
| **Nemours** | 11 | Adults | Mixed | Old, limited | 1990s. Small. |
| **CDSD** (Chinese Dysarthric) | 44 | 39 adults, **5 under 18** | Mixed | Research request | **Mandarin.** The only corpus with any children, and it's five of them in the wrong language. |
| **EasyCall** | ~30 | Adults | Mixed | Public | Italian. Command words. |

**No English pediatric dysarthric speech corpus is publicly available.** SAP, the largest effort in the field, explicitly requires participants to be 18 or older.

## Where pediatric data actually lives

It exists. It's in labs, not repositories.

**Katherine Hustad, University of Wisconsin–Madison.** Runs the largest longitudinal study of speech development in children with CP in the world — recordings of the same children from age 2 through adolescence, across many years. Kristen Allison (now at Northeastern) did her PhD in that lab; the two JSLHR papers on acoustic classification of pediatric dysarthria come from it — twenty 5-year-olds with CP, twenty typically developing controls. This is exactly the data you need. It is not public. Access would be a collaboration, not a download.

**DeLuca's clinic.** If Fralin's Neuromotor Research Clinic records sessions — and intensive therapy programs often do — that's a pediatric CP speech source. Whether any of it is usable depends on consent language, IRB scope, and whether audio was captured at all.

**Hustad is the person to know about.** If DeLuca knows her — and in pediatric CP research, she almost certainly does — that introduction is worth more than any dataset search.

## Why this is harder than adults

Even with data, pediatric dysarthria is a different problem from what TORGO trained you on:

- **Developmental, not acquired.** TORGO's speakers learned to speak typically and then lost precision (ALS) or never had it but as adults (CP). Children with CP are learning to speak *through* the impairment. The error patterns are different and change as the child grows.
- **Children's speech is already hard for ASR.** Higher pitch, shorter vocal tract, less stable articulation, smaller vocabulary. Off-the-shelf Whisper is worse on typically developing 5-year-olds than on adults. Dysarthria compounds that.
- **The variability problem, doubled.** Section 6 of your voice-filter code exists because dysarthric adults vary utterance to utterance. Children vary more. Children with dysarthria vary most.
- **Consent and ethics.** Every recording needs a parent's consent and, above a certain age, the child's assent. IRB scrutiny for minors is much higher. This is not a weekend of scraping.

## What I'd actually do

**1. Don't try to build a pediatric model from public data. There isn't any.** Spending a month hunting will produce five Mandarin speakers.

**2. Apply to SAP anyway.** It's adults, but it's 400 hours across five etiologies and it would let you test whether your adaptation generalizes beyond TORGO's eight speakers — the leave-one-speaker-out question you owe, at scale. They're accepting proposals from nonprofits. A high school student with a released model, a TORGO maintainer's endorsement, and a written paper is a plausible applicant. Frank Rudzicz might be willing to say a sentence in support.

**3. Ask DeLuca about Hustad.** One sentence: "Is there anyone collecting pediatric CP speech recordings that a project like this could eventually work with?" If she says Hustad, you have your path. If she says her own clinic, better.

**4. Reframe what "versatile" means for now.** The honest scope of the current model is *adult acquired dysarthria from CP and ALS*. It says that on the model card. Pediatric is a stated future direction, not a claim. Adding SAP's five etiologies would make the model meaningfully more versatile — across adults — and is achievable in months, not years.

**5. Design for pediatric data collection, don't wait for it.** If a clinic partnership materializes, you want to be ready: a consent template for minors, a simple recording protocol (the TORGO prompt list is a reasonable start), and the app itself as the recording tool with opt-in local storage. That's a document and a feature, and both are cheap to prepare before you need them.

## The strategic read

The absence of pediatric data is a gap in the field, not just in your project. Nobody has trained an open dysarthria model on children because nobody has released the data to do it. If DeLuca's network gets you access — or if her clinic becomes a collection site — you're not catching up to the field. You're ahead of it.

That's the version of this to say out loud, carefully, at the right moment.
