---
name: x-unslop
description: Remove AI writing patterns from issue text, tracker comments, and other technical text without changing facts. x-create-issue and x-issue-comment apply it before they post.
argument-hint: "[text, file path, or nothing for the last draft]"
disable-model-invocation: true
effort: low
---

# Unslop

Edit text to remove AI writing patterns. Keep the meaning, the facts, and the tone.

## Input and output

- Input: text in the arguments, a file path, or the last draft in the conversation.
- Output: only the edited text, ready to paste, in the same format and language. No list of changes and no comment about the edit.
- If the text breaks no rule, return it unchanged. Do not make the text longer unless a sentence was unclear.

## Do not change

- Facts. Never add a number, name, quote, result, or cause that the text does not have. If a rule asks for a number the text does not give, leave the sentence as it is: invented detail is worse than vague text.
- Quoted text, error messages, log lines, code, identifiers, issue keys, URLs, and commands.
- Structure set by the calling skill: section labels such as `**Changes**` or `## Acceptance criteria`, line labels such as `To check:`, checklists, tables, and tracker markup. Keep every label and prefix exactly as written.
- Negations, limits, numbers, units, and safety instructions. After the edit, compare them with the original and restore any that changed.

## Rules

Rule numbers are stable ids that other skills can cite. Rules 3 to 33 follow pstack `unslop` and keep its numbers, so the gaps are on purpose. Rules from 40 are local.

3. No trailing "-ing" phrases that add no fact ("highlighting...", "ensuring...").
5. No vague attributions ("experts believe"). Name the source or delete.
7. No AI vocabulary: additionally, crucial, delve, enhance, foster, landscape, pivotal, robust, seamless, showcase, testament, underscore, vibrant.
8. Say "is" or "has", not "serves as", "stands as", "boasts", "features".
9. No "not just X, but Y". State the point.
10. Don't force ideas into threes.
11. One name per thing. Repeat it.
12. No "from X to Y" unless X and Y sit on a real scale.
13. No em dashes, en dashes, or hyphens used as dashes, and no parentheses in their place. Use a period or a comma.
14. A colon goes before a list or an example, never mid-sentence as a connector.
15. Don't bold every proper noun or acronym.
16. No bold label and colon that restates its line ("**Performance:** Performance improved..."). A bold lead-in that ends in a period and adds new detail is fine.
17. Sentence case headings.
18. No decorative emojis.
19. Straight quotes.
20. No chatbot phrases ("I hope this helps!", "Let me know if...").
22. No praise or agreement openers. Respond directly.
23. Cut filler. "In order to" becomes "to". Delete "it is important to note that".
24. One hedge at most: "may".
25. No generic conclusions. State specific plans or facts.
26. No abstract metaphor nouns: substrate, wedge, vector, nexus, primitive, harness, surface, scaffolding, paradigm, ratchet, north star, flywheel. Use the concrete word.
27. Say what it does, not how it feels. Name the mechanism or the number. Cut a sentence that could appear unchanged in another project's issue or docs.
28. One idea per sentence. Split a sentence the reader has to reread.
29. Active voice. Name the actor unless it is unknown or doesn't matter.
30. Cut adverbs or use a stronger verb. Give the number.
31. Use the plain word: "use", not "utilize" or "leverage".
32. No metaphor, aphorism, personified code, or figurative verb where a literal phrase exists.
33. Write whole sentences with their articles and verbs in prose. Fragments are fine in bullets and checklist items. Spell out arrows and invented abbreviations; standard acronyms such as API, DB, and HTTP are fine.
40. Never invent data, quotes, names, or results.
41. Don't argue both sides. State the decision, and give a counterpoint in one sentence at most.
42. No pep talk or cheering ("Great news", "Exciting update"), and no "As a developer, I..." openers.
43. No exclamation marks. No "..." as a link between sentences.
44. No emoji as bullet points.
45. Use a sentence when the content fits in one sentence. Use bullets only for real lists.
46. No closing summary line at the end of a paragraph or comment.
47. Use the real names of symbols, flags, commands, and UI elements, not a description of them.

## Other languages

Rules that describe a pattern, such as filler, hedging, passive voice, dashes, and closing summaries, apply in every language. The word lists in rules 7, 26, and 31 are English: in other languages, cut the local words that do the same job. Keep the text in its own language.

## Example

Before:

```markdown
**Changes**
- Successfully implemented a robust fix that ensures the CSV export now seamlessly includes archived orders — a crucial improvement!
```

After:

```markdown
**Changes**
- CSV export includes archived orders.
```
