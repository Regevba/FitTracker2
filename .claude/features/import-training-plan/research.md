# Import Training Plan — Research

> Status: Phase 0 research
> Framework: PM-flow v4.3
> Date: 2026-04-12

## 1. What is this solution?

Allow users to bring training plans into FitMe from external sources:

- CSV / JSON exports
- pasted text
- AI conversation output
- PDFs and photos later

The core job is to turn outside workout structure into a FitMe-native plan quickly and safely.

## 2. Why this approach?

FitMe already has a strong training experience, but fixed plan assumptions create friction for users who already have a coach plan, another app history, or an AI-generated program. Import removes a major adoption barrier.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Chosen? |
|---|---|---|---|
| Start with structured text and paste flows | fast, high utility, lower ambiguity | still needs mapping logic | yes |
| Full OCR/PDF import first | broad source coverage | harder parsing, slower to validate | later |
| Manual re-entry only | simple to build | too much user effort | no |

## 4. External and competitive references

- Hevy and Strong: import/export expectations make migration easier
- Coach-generated spreadsheets and text plans are common
- AI-generated plans from ChatGPT and Claude are increasingly a real user input source

## 5. Primary research questions

- which source formats should ship first
- how exercise mapping should resolve to FitMe's exercise library
- how much manual review is acceptable for ambiguous matches
- whether imported plans replace or supplement the default split
- how much of the original AI prompt/output should be preserved for future regeneration

## 6. UX implications

- import must feel progressive, not brittle
- easy matches should auto-accept
- ambiguous matches need a clear review step
- users should see the imported structure before committing it

## 7. Technical feasibility

Phase 1 is feasible with:

- structured parser for CSV/JSON/text
- exercise-name normalization and mapping
- import preview and conflict handling
- saved original import payload for re-review/debugging

## 8. Risks

- poor mapping quality breaks trust fast
- too many review steps make import slower than manual setup
- AI conversation parsing can become too permissive without good guardrails

## 9. Draft success metrics

- import success rate > 80%
- exercise mapping accuracy > 90%
- time to first usable imported workout < 2 minutes

## 10. Recommended approach

Start with the highest-confidence import surfaces:

1. CSV / JSON
2. pasted structured text
3. AI conversation / markdown parsing

Then expand into OCR/PDF flows once the mapping and preview experience are solid.
