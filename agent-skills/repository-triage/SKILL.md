---
name: repository-triage
description: >-
  Inspect a repository and propose exactly one next action in priority order:
  what should likely be deleted, otherwise what missing .gitignore work should
  be added, otherwise what belongs in a single incremental commit. Use when
  the user wants commit-hygiene triage, separation of intentional source
  changes from noise, or a grounded review of modified, untracked, generated,
  cache, scratch, log, and local-only files.
---

# Repository Triage

Inspect the current repository and produce an advisory proposal for exactly one next action. Choose in strict priority order: deletion candidates first, then missing `.gitignore` work that should be added now, then a single incremental commit. Do not choose the `gitignore` tier merely because ignored-noise paths exist or `.gitignore` is already modified. Base every recommendation on observed repository state rather than file-extension heuristics.

## Core Rules

- Remain advisory only.
- Do not stage files.
- Do not edit `.gitignore`.
- Do not delete files.
- Do not run destructive commands.
- Inspect enough evidence to classify modified tracked files, untracked files, existing ignore rules, and plausible delete candidates before choosing the winning proposal tier.

## Workflow

1. Establish repository context.
- Check repository status, staged versus unstaged state, and repository root.
- Inspect `.gitignore` and related ignore files when present.
- For plausible ignore candidates, check whether the noisy path is currently ignored and whether the relevant rule is already present in tracked `.gitignore` changes.
- Inspect recent commit history or repository conventions when they materially affect whether generated files, notebooks, fixtures, snapshots, or data belong in version control.

2. Inspect changed material.
- Review diffs for modified tracked files.
- Inspect untracked files and directories.
- Open files when names alone are not enough to classify them correctly.
- Check whether untracked or modified files are referenced by changed source, config, or build files.
- For candidate noise paths, confirm both the path status and the source ignore rule with `git check-ignore -v` or equivalent plus the current `.gitignore` diff.

3. Classify candidates.
- Recommend a single incremental commit only for intentional, coherent, source-controlled changes that fit a sensible next commit.
- Recommend `.gitignore` entries only for reproducible generated artefacts, caches, machine-local files, secrets, editor noise, or similar non-source items when the ignore problem is unresolved in the current worktree.
- Recommend deletion only when the evidence supports junk, stale outputs, accidental duplicates, obsolete scratch material, or abandoned generated files.
- If the needed ignore rule is already present in modified or staged `.gitignore` and the noisy path is already ignored, treat that `.gitignore` change as normal tracked work and continue evaluating for a single incremental commit.
- After classifying all three categories, choose exactly one proposal tier in this order:
  1. Delete
  2. Gitignore
  3. Single incremental commit

4. Verify the proposal.
- Check that each recommendation matches inspected evidence.
- Check that ignore patterns are precise rather than broad.
- Check that delete recommendations are safe enough to be useful.
- Check that the incremental-commit proposal would produce a coherent next commit.
- Check that lower-priority recommendations are suppressed unless they matter to explain uncertainty in the chosen proposal.

## Inspection Expectations

- Treat the task as incomplete until modified tracked files have been considered.
- Treat the task as incomplete until untracked files have been considered.
- Treat the task as incomplete until existing ignore rules have been considered.
- Treat the task as incomplete until plausible delete candidates have been considered.
- Use more than `git status` when more inspection would materially improve correctness.
- Follow another inspection path when the first pass is inconclusive.
- Do not skip delete or ignore inspection just because the repository already appears commit-ready.

## Decision Principles

### Single Incremental Commit

- Use this tier only when no delete-tier or gitignore-tier proposal is credible.
- A single incremental commit is one proposed commit, not multiple grouped commit bullets.
- Prefer full-file inclusion when a file contains one coherent logical change.
- Recommend hunk-level staging sparingly.
- Recommend hunk-level staging only when one file clearly contains separable logical changes that belong in different commits.
- Do not recommend staging generated outputs, caches, logs, secrets, machine-local files, or transient artefacts.
- `.gitignore` may be included in the proposed commit when it already contains the rule that solved the ignore problem.
- The proposed commit may include all unstaged content or only part of it, but it must represent one coherent next commit.
- You may name many included paths, but they must all appear under one recommendation.
- If no coherent incremental commit exists, say so briefly instead of forcing a weak proposal.

### Gitignore

- Use this tier only when a new ignore rule still needs to be added.
- If the relevant rule is already present in modified or staged `.gitignore` and the noisy path is already ignored, do not choose this tier.
- Propose the narrowest ignore pattern that solves the observed problem.
- Keep recommendations consistent with the repository's existing ignore conventions.
- Do not hide likely source files or important project artefacts without strong evidence.

### Delete

- Use `delete` when the evidence is strong that the item is junk or obsolete.
- Use `review before delete` when the item looks disposable but intent is still somewhat uncertain.
- Distinguish likely duplicates, stale scratch files, temporary outputs, and abandoned generated files from intentional research or project artefacts.
- Any delete-tier item, including `review before delete`, wins over gitignore and incremental-commit proposals.

## Reasoning Discipline

- Base claims only on material inspected in the current repository.
- Label inferences as inferences when evidence is mixed.
- Do not assume every untracked file is junk.
- Do not assume every modified file should be staged.
- Do not default to partial staging unless the separation is clearly worthwhile.
- Do not present multiple proposal tiers in one answer.

## Output Contract

Return exactly these sections, in this order:

1. `Proposal`
2. `Notes`

Use flat bullet lists only.

- In `Proposal`, include recommendations from exactly one tier only: delete, gitignore, or single incremental commit.
- If the chosen tier is `single incremental commit`, `Proposal` must contain exactly one bullet total.
- That bullet represents one commit only, even if it lists many files.
- Do not split one commit across multiple bullets.
- For every recommendation, include the path.
- For incremental-commit recommendations, say `file` or `hunks` explicitly.
- For hunk recommendations, describe the logical split briefly.
- For `.gitignore` recommendations, propose the minimal ignore pattern and tie it to the observed noise it solves.
- For delete recommendations, distinguish between `delete` and `review before delete` when useful.
- In `Notes`, include only the most decision-relevant caveats or uncertainties.
- If some changed paths should be excluded from that commit, mention them only in `Notes`.
- Do not include empty sections or placeholder bullets for suppressed tiers.
- If no coherent incremental commit exists and neither higher-priority tier applies, say so briefly in `Proposal`.
- Before responding, perform a self-check: `Proposal` contains exactly one bullet total. If the chosen tier is `single incremental commit`, that bullet is the one commit recommendation.
- Keep the final answer concise, dense, calm, and specific.

## Examples

- Missing ignore rule: a generated log file is untracked, not currently ignored, and no relevant `.gitignore` change exists. Choose `gitignore`.
- Ignore fix already present: the same file is already ignored by a modified `.gitignore` entry in the worktree. Do not choose `gitignore`; if the tracked changes are coherent, choose `single incremental commit`.

Incorrect:
- Single incremental commit, file: a, b
- Single incremental commit, file: c, d

Correct:
- Single incremental commit, file: a, b, c, d
