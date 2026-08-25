# ~/.codex/AGENTS.md

## Environment
You are in a Windows Subsystem for Linux (WSL) environment. Some windows features (such as access to Microsoft office or PowerShell) can be accessed through powershell, which is in path. For example, `pwsh.exe -c "explorer"`.

## Python
- Always run python through `uv`, using virtual environments rather than system installations.
- Do not install any packages without explicit permission from the user. If you need a certain package to perform your task, or to make your task significantly easier, get explicit permission from the user first. If you have explicit permission, you make create a `.venv` folder and run `uv add` or `uv pip install` outside of sharepoint folders.

## Sharepoint
Never modify anything in sharepoint (or symlinked to a file or folder in sharepoint) without express user permission. Do not create temporary files, scripts, or audit files in sharepoint unless explicitly to - these should remain outside sharepoint.

## Artifacts and outputs
Whenever creating artifacts or outputs - such as a document, presentation, spreadsheet, website, or image, assume the design should follow the Scarlatti design guidelines and use the corresponding skill,unless directed otherwise by the user

## Reviewing outputs
After tasks creating or modifying files, spawn separate subagents to review the outputs. These reviews and documentation updates should be strictly scoped to the changes made as part of the main task. These outputs could be code changes, or documents. Do not perform these checks for chat-only interactions. Spawn one subagent per bullet point:

- Review code, checking for where new code could be replaced with existing code to keep the results concise.
- Review module, class, and function lengths, suggesting where they could be broken out into new modules, classes, or functions to keep code concise.
- Review the outputs in relation to the users original request, making sure it is aligned with the user's intent.
- Review for logical consistency - suggesting fixes to align with the users original intention. Any logical issues with the user's design should be flagged back to them, rather than modifying their requested logic.
- If the output is a code change and the project contains a test suite, spawn an agent to determine if the test suite needs to be updated. If it does, update the test suite.
- If any new environment variables were added, ask the user if they would like to add them to the .env template.
- Update any docstrings, documentation, or READMEs for the project.

Any changes to the main artifact should be passed back to the main agent, which can then decide to implement or not implement that suggestion. Updates to documentation and READMEs can be performed by the subagents, rather than by the main agent (unless they are the main artifacts).

Only after the reviewers have ran and any additional changes have been made, run any test suite if present. If any errors arise because of the changes you have made, iterate your code to pass the tests in good faith, then rerun the test suite. Try to minimise the number of times the test suite runs. Test failures due to changes made by the user or other agents outside the scope of your change do not require any code changes, but should be raised to the user.

## Response wording

- In commentary and final replies, avoid stock AI and corporate-software phrasing. Do not use the terms below as filler, vague praise, or substitutes for naming the actual file, function, target, data change, test, or result.
- These terms are not banned. Retain them when quoting text, referring to an identifier, using established project terminology, or when they are the most accurate words available. Do not distort technical meaning merely to avoid a listed term.
- Prefer plain English and concrete statements. Say what changed, why it changed, what was checked, what happened, and what remains unknown.
- Avoid stacking several listed terms into an abstract sentence.

Treat these words and phrases with particular suspicion:

`canonical`; `gate`, `gated`; `readiness`; `mapped`, `mapping`;
`variant`; `downstream`; `upstream`; `surface`, `surfaced`; `flow`;
`path`, `codepath`; `lifecycle`; `contract`; `invariant`; `boundary`;
`layer`; `primitive`; `abstraction`; `orchestration`, `orchestrate`;
`plumbing`, `plumb`; `wiring`, `wire up`; `scaffold`, `scaffolding`;
`hook`; `seam`; `affordance`; `mechanism`; `pathway`;
`integration point`; `touchpoint`; `entry point`; `source of truth`;
`first-class`; `end-to-end`; `holistic`; `robust`; `resilient`;
`graceful`, `gracefully`; `seamless`, `seamlessly`; `deterministic`;
`idempotent`; `explicit`, `explicitly`; `intentional`, `intentionally`;
`consistent`, `consistently`; `clean`, `cleanly`; `coherent`;
`comprehensive`; `modular`; `extensible`; `composable`; `reusable`;
`maintainable`; `production-ready`; `future-proof`;
`backwards-compatible`; `well-defined`; `well-scoped`; `lightweight`;
`minimal`; `targeted`; `surgical`; `bounded`; `centralised`; `unified`;
`consolidated`; `normalised`; `aligned`; `reconciled`; `validated`;
`sanitised`; `hydrated`; `resolved`; `propagated`; `threaded`; `routed`;
`delegated`; `encapsulated`; `decoupled`; `isolated`; `preserved`;
`enforced`; `instrumented`; `exposed`; `consumed`; `emitted`;
`persisted`; `materialised`; `derived`; `fallback`; `guardrail`;
`escape hatch`; `happy path`; `failure mode`; `edge case`;
`blast radius`; `regression`; `parity`; `semantics`; `ownership`;
`responsibility`; `guarantees`; `assumptions`; `concerns`;
`dependencies`; `observability`; `telemetry`; `ergonomics`.
