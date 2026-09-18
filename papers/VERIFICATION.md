# Claim-by-claim verification for *The Device Is Not the Problem*

> **Updated for the second draft.** New claims added in the rewrite are marked ⊕. The rewrite added: information-rate figures (§2.2), the race/class access disparities (§3.3), Millar et al. numbers (§6.2), Smidt & Pebdani (§8), the causal-edge table (§9.2), and your own empirical results (§10.2).

## ⊕ New in the second draft — verify before submission

| Claim | Where | Status |
|---|---|---|
| Speech carries ~39 bits/second across languages | §2.2 | **Verified from memory only.** Coupé, Oh, Dediu & Pellegrino 2019, *Science Advances* 5(9). Confirm the 39 bits/s figure and the citation. |
| A 60-symbol grid selection carries ~6 bits; proficient users ~1 selection/second | §2.2 | **Back-of-envelope.** log2(60) ≈ 5.9 bits is arithmetic. The 1/sec selection rate is a reasonable estimate, not a citation. Either cite a rate-enhancement study for it or label it as an estimate in the text. |
| 84% white vs 32% minority families had an AAC device; >50% of minority families didn't know what AAC is | §3.3 | Verified from CHLA summary of a study on minimally verbal children with autism. **Get the primary paper** — it's a Children's Hospital Los Angeles study; find the journal citation and add it to references. |
| Black preschoolers receive less AAC intervention; 75% under 60 min/week | §3.3 | Verified. Pope, Light & Franklin 2022, *AJSLP* 31(5). Confirm page numbers 2159–2174. |
| Millar et al. 2006: 23 studies, 67 individuals, 89% increased, 11% unchanged, 0% decreased | §6.2 | Verified. PubMed 16671842. |
| Smidt & Pebdani 2023 — capability approach, Sen, multimodal choice framing | §8 | Verified. PubMed 37210662. *AAC* 39(3), 198–206. |
| Wheeler et al. 1993 FC controlled study | §7 | Standard reference. Confirm *Mental Retardation* 31(1), 49–60. |
| Your own numbers in §10.2 (2.9/48.0, severity gradient, 84.4→34.6, 8.1→67.6, 37/59, pooled 34.6 vs personal 50.8, 1.44%, 152 min, 2.5h) | §10.2 | These are from your `results/` folder. **Re-check every one against `comparison.csv`, `by_severity.csv`, and the model card** before submitting. One transposed digit here is worse than anywhere else in the paper because it's the part you can't blame on a source. |

---

## Original verification list (first draft) — still applies

Every factual claim in the paper, sorted by how confident you should be. **Do not submit until the third list is cleared.** A reviewer in this field will check these, and one fabricated citation discredits the whole paper.

---

## Verified against a primary or reliable secondary source during drafting

These I read the source for. Safe to cite as written.

| Claim | Source | Where in paper |
|---|---|---|
| 39.35% of AAC systems still in use >1 year; 275 ASHA SIG 12 respondents; five abandonment constructs (not maintaining/adjusting, attitude, lack of training, lack of support, poor fit); three success constructs (support, attitude, fit) | Johnson et al. 2006, PubMed 17114167 | §1, §3, §5 |
| 29.3% abandonment; 227 adults; four predictors — lack of user opinion in selection, easy procurement, poor performance, change in needs; peaks year 1 and year 5+ | Phillips & Zhao 1993, PubMed 10171664 | §1, §3 |
| AAC rate 12–18 wpm vs 125–185 wpm speech; under 10% of speech rate; LLM-assisted best ~25.75 wpm | Multiple; see "Bridging the Communication Rate Gap" (Springer 2023) | §2 |
| Light et al. 1985: partners take majority of turns, offer few opportunities, ask disproportionate yes/no questions | Cited in Kent-Walsh & McNaughton 2005 and the 2015 meta-analysis | §2, §5 |
| Kent-Walsh et al. 2015 meta-analysis of partner instruction exists and finds it effective | ResearchGate 278045316 | §5 |
| Medicare NCD 50.1, January 2001; SGDs covered as DME | Center for Medicare Advocacy, June 2014 | §4 |
| April 1, 2014 capped rental; 1986–87 reference period; SGDs purchased 99.3% of the time in 2012; "has not impressed CMS" | CMA, June 2014 (primary source, read in full) | §4 |
| Capped rental → device not available during Part A facility stay; the hospice quotation | CMA, June 2014 | §4 |
| September 1, 2014 rule against any device with non-speech capability; reverses 2001 NCD language about laptops/PDAs; CMA's reading of the motive as avoiding perception of paying for "technology" | CMA, June 2014 | §4 |
| Steve Gleason Act 2015; permanent extension via Enduring Voices Act | Congressional sources, Klobuchar release | §4 |
| ~40% of SLP graduates unprepared for AAC; 52% not confident to assess/treat; 13-study scoping review | *AAC* 2024, PubMed 38619086 | §3 |
| "They absolutely love it, or they're terrified of it" — Australian SLP study title | *IJLCD* 2025, Wiley 10.1111/1460-6984.70262 | §3 |
| Donnellan 1984 criterion of least dangerous assumption, exact formulation | ERIC EJ305413 | §7 |
| "Presumed competence" coined by Biklen 1990 in facilitated communication context | Multiple, incl. Wikipedia and PrAACtical AAC | §7 |
| ASHA Leader 2018: presuming competence without feature-match is not the least dangerous assumption; real harm observed | *ASHA Leader* 23(12), 2018 | §7 |
| Parette & Scherer 2004: visibility, aesthetics/age-appropriateness, family fear that device reliance prevents skill development | ERIC EJ754131 | §6 |

---

## Cited from background knowledge — confident, but confirm the citation details

I'm confident these are real and correctly characterised. I did not read them during drafting, so check author lists, years, and page numbers before submission.

| Claim | Citation as written | What to check |
|---|---|---|
| Turn-taking gaps are sub-second and near-universal across languages | Stivers et al. 2009, *PNAS* 106(26) | Confirm page range 10587–10592 and full author list (Stivers, Enfield, Brown, Englert, Hayashi, Heinemann, Hoymann, Rossano, de Ruiter, Yoon, Levinson) |
| Discredited vs discreditable | Goffman 1963, *Stigma* | Standard. Confirm edition/page if quoting directly — paper paraphrases, so no page needed |
| Light, Collier & Parnes 1985 exact title | "Communicative interaction between young nonspeaking physically disabled children and their primary caregivers: Part I — Discourse patterns," *AAC* 1(2) | Confirm title and pages 74–83 |
| Kent-Walsh & McNaughton 2005 | *AAC* 21(3), 195–204 | Confirm pages |
| Kent-Walsh et al. 2015 co-authors | Murza, Malani, Binger | Confirm author list and pages 271–284 |
| Facilitated communication shown in controlled studies to produce facilitator-authored output | No citation given in paper | **Add one.** Wheeler, Jacobson, Paglieri & Schwartz 1993 (*Mental Retardation* 31(1)) is the standard reference. Or cite the ASHA 2018 position statement on FC. |
| AAC use not associated with reduced speech development; associated with gains in several studies | No citation given in paper | **Add one.** Millar, Light & Schlosser 2006, *JSLHR* 49(2), 248–264, is the meta-analysis everyone cites for this. |

---

## Must verify before submission — I am not certain

| Claim | Where | Problem |
|---|---|---|
| First author of the 2024 SLP confidence scoping review is "Sanders, E. J." | References | **I may have guessed this.** Open PubMed 38619086 and copy the actual author list. If it isn't Sanders, fix it everywhere. |
| Medicare pays for SGD software on a general computing device but not the device itself (HCPCS E2511 vs E2500–E2510) | §4 | This came from earlier work in this project (CMS Article A52469). Re-open that article and confirm the current rule. Coverage rules change. |
| Steve Gleason Enduring Voices Act "enacted 2018" | §4, References | The search confirmed a bill to make the 2015 Act permanent. Confirm enactment year and public law number. |
| "Recent work finds partners rate AAC users as less capable or disengaged when output lags" | §2 | I have this from a search summary, not the paper. Find the actual study — it's likely one of the two arXiv papers on AAC interaction (2024–2025) or cited within the rate-gap chapter. Cite it specifically or soften to "has been reported." |
| "There is no procedure code for teaching a mother to wait" | §5 | Rhetorically strong, and I believe it's true that no CPT code covers partner instruction as a standalone service — but confirm. Some SLPs bill partner training under the client's treatment code. If so, rephrase: "no funded role dedicated to" rather than "no procedure code." |
| Abandonment rate "has not moved substantially" across device generations | §1, §8 | This is the paper's central claim and it is an **argument from absence**. The paper says so in §10. But be ready for a reviewer to ask for any longitudinal data at all. If you can find one more retention figure from 2015 or later, add it. If you can't, that absence is itself worth stating more forcefully. |

---

## Things I inferred, and said so in the text

These are marked as inference in the paper. A reviewer may push on them; that's fine, they're the paper's contribution. Just don't let anyone mistake them for findings.

- The yes/no question is the partner's adaptation to the clock (§2). Light documented the pattern; the causal reading is mine.
- Every actor's role ends at delivery, so adjustment has no owner (§3). Structural inference from how the chain is organised.
- The DME category encodes a conception of speech as bodily function rather than social act (§4). Interpretive.
- Family refusal of AAC is a refusal to concede, not a knowledge deficit (§6). Interpretive, and probably the claim most likely to draw pushback. Worth keeping — it's the most original thing in the section — but be ready to defend it.
- The feedback loop (§8). A model, labelled as one.

---

## Two things to decide before submitting

**Section 9, final paragraph.** The paper mentions your own tool. I kept it to one paragraph and made it self-critical, which is the only way it works in a paper like this. But some venues will see any mention of the author's product as a conflict. If you submit somewhere strict, cut the paragraph and put a one-line disclosure in the acknowledgements instead.

**Authorship.** This is single-authored. Melodie isn't on it. That's correct for this paper — it's your argument and your writing — but if she contributed to your thinking on any of it, an acknowledgement line is cheap and right.
