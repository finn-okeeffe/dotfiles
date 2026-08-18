---
name: can-finn-eat-here-skill
description: Determine whether Finn can eat a satisfactory meal at a named restaurant and location by researching current menus, restaurant statements, HappyCow, ordering platforms, and other public evidence. Use when asked whether a restaurant, cafe, takeaway, food venue, or particular branch is suitable for Finn's vegan diet, peanut and pecan intolerance, and avoidance of canola or rapeseed oil.
---

# Can Finn Eat Here?

Research the specified restaurant and branch, apply Finn's requirements conservatively, and return a concise verdict supported by current evidence.

## Apply Finn's Requirements

Treat a meal as suitable only when all of these conditions are met:

- It is vegan. Honey is an explicit exception and is acceptable.
- It contains no peanuts or pecans as ingredients. Warnings such as "may contain" or "contains traces" are acceptable; do not treat more than trace quantities as acceptable.
- It can be prepared without canola oil or rapeseed oil. Treat canola and rapeseed as the same oil, and check dressings, sauces, marinades, frying oil, grill oil, and cooking spray as well as the main ingredients.
- It is a satisfactory main meal: either at least one substantial main, or multiple suitable entrees/small plates that can reasonably be combined into a substantial meal. Sides, snacks, chips, or one insubstantial entree do not qualify. In particular, do not count a lone entree with no meaningful protein as a main.

Do not reject a dish merely because the venue handles peanuts or pecans or gives a trace warning. Assess shared-equipment or preparation evidence if it suggests more than trace exposure, and recommend calling when that risk is material but unclear. Reject a dish containing either nut unless reliable evidence shows the ingredient can be omitted and the resulting dish still meets every other requirement.

## Research the Restaurant

1. Confirm the exact venue and location. If branches have different menus, hours, or practices, assess only the requested branch. State any location assumption when the request is ambiguous.
2. Search the restaurant's official website first. Inspect the current menu, allergen information, dietary key, FAQs, ingredient statements, and branch-specific pages. Follow menu PDFs and relevant linked pages.
3. Check HappyCow for corroboration and recent diner reports. Also search useful public sources such as official social accounts, Google results or reviews, delivery platforms, booking sites, and credible local forums.
4. Search specifically for the restaurant name with terms such as `vegan`, `plant based`, `allergen`, `peanut`, `pecan`, `canola oil`, `rapeseed oil`, `cooking oil`, and `frying oil`.
5. Identify concrete meal candidates. For each candidate, establish vegan status, peanut/pecan ingredients, oil used in every component, and whether it is substantial enough to qualify alone or in combination.
6. Prefer current, branch-specific, first-party evidence. Record when menus, reviews, or statements were published or accessed. Treat old menus, undated snippets, and third-party claims as weaker evidence, and call out material conflicts or staleness.
7. Cite the most useful public sources with direct links in the summary. Never imply that a source confirms an ingredient or preparation detail it does not address.

If a website blocks access, use indexed snippets and other public sources, then lower confidence accordingly. Do not contact the restaurant, submit forms, post publicly, or place an order; recommend a call when public evidence is insufficient.

## Choose the Verdict

Use exactly one of these takeaway lines:

- `_Finn can definitely eat here._`
- `_Finn can definitely **not** eat here._`
- `_Finn can maybe eat here, call up for more information._`
- `_I could not find any information on the restaurant._`

Choose **definitely eat** only when current evidence establishes at least one qualifying meal across all four requirements. Name the qualifying main or entree combination.

Choose **definitely not eat** only when reliable current evidence rules out every plausible qualifying meal. A menu with no qualifying main or viable qualifying entree combination is sufficient when it appears complete and current, after accounting for the honey exception and reliably evidenced modifications. Explain the disqualifying requirement; do not infer unsafe oil or nuts merely from missing information.

Choose **maybe** when at least one plausible substantial vegan meal exists and no evidence disqualifies it, but its peanut, pecan, oil, or modification details remain unknown. Missing cooking-oil information will usually produce this verdict. State exactly what to ask the restaurant, including hidden sources of oil and whether any proposed substitution remains vegan and nut-free.

Choose **could not find information** when no reliable menu or other evidence reveals whether a plausible qualifying meal exists. Do not use this verdict merely because oil or allergen details are missing when a plausible vegan meal is visible; use **maybe** instead.

## Format the Answer

Return only:

1. One approved takeaway line, on its own line.
2. One short paragraph that explains the evidence, names the candidate meal or reason none qualifies, notes relevant dates or uncertainty, and includes direct source links. For a **maybe** verdict, end with the precise questions Finn should ask when calling.

Keep the paragraph focused on the decision. Do not add headings, bullet lists, a separate sources section, or general dietary disclaimers.
