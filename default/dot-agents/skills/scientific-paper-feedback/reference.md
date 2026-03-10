# Scientific Paper Feedback — Reference

## Guideline sources (fetch when reviewing)

| Source | URL | Use |
|--------|-----|-----|
| jerabaul29 (raw) | `https://raw.githubusercontent.com/jerabaul29/guidelines_writing_papers/main/README.md` | Style, LaTeX, figures, structure, content |
| Stanford Widom | `https://cs.stanford.edu/people/widom/paper-writing.html` | Structure, mechanics, grammar, abstract, intro, citations |

## Violation report format

Each violation must include:

- **Location:** Line number(s) preferred; else section + position.
- **Excerpt:** 1–3 sentences of the exact text.
- **Guideline:** Rule or ID violated (e.g. F:S2, Stanford: "which vs that").
- **Suggestion:** Concrete correction or rewrite.

## Guideline IDs (jerabaul29) — for citing in feedback

- **F:X** — Meta (version control, LaTeX, spellcheck, consistency).
- **F:G** — General (KISS, brief, clear story, nomenclature, no speculation).
- **F:S** — Style (no hyperboles, present tense, short sentences, consistent terms, terse English, equation punctuation, avoid passive/double negation).
- **F:L** — LaTeX (citations `\citep`/`\citet`, treat .tex like code).
- **F:F** — Figures (detailed captions, readable, referred in text).
- **F:A** — Appendix.
- **F:M** — Methodology.
- **F:R** — References (bib, no duplicates).
- **F:B** — Abbreviations (define at first use).
- **S:T** — Theory; **S:C** — Crediting.

Use these IDs when reporting violations (e.g. "F:S2", "F:L3"). For Stanford, cite the section or rule in words (e.g. "Stanford: variables defined before use", "Stanford: avoid 'for various reasons'").
