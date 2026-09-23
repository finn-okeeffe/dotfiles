---
name: zellij-cli
description: Inspect and control Zellij sessions, tabs, panes, and running terminal programs through the CLI. Use when the user asks to interact with Zellij or with a process already running in a Zellij pane.
---

# Work with Zellij through the CLI

In this WSL setup, expect to be running under zsh inside Zellij. Use Zellij's CLI to work with the user's existing terminal sessions. An ordinary shell command for the agent's own work does not need a Zellij pane unless the user wants to see or keep it there.

## Find the right target

1. Check `ZELLIJ_SESSION_NAME` for the session inherited by the current process. If it is absent or the user means another session, run `zellij list-sessions --no-formatting` and check which sessions are active; the list can include exited sessions. Choose the named session from the user's request or the available context; ask if more than one plausible session remains.
2. Use `zellij --session "$session_name" action list-tabs --json` and `zellij --session "$session_name" action list-panes --json` to identify the tab and pane. In pane JSON, combine numeric `id` with `is_plugin` to form the pane ID. `list-clients` can show where connected users are focused. If `ZELLIJ_PANE_ID` is available, it identifies the current terminal pane, but do not assume that the focused pane is the one the agent should control.
3. Use stable tab IDs and pane IDs such as `terminal_3` or `plugin_2`. Inspect a pane's title, command, working directory, and state before sending input. Recheck if the user or another process may have changed the session. Put the global `--session` flag **before** `action`, `run`, or `subscribe`.

In Codex's restricted shell, Zellij actions may say `There is no active session!` even when `list-sessions` marks the session as current. A read-only retry outside the sandbox can distinguish this access restriction from an exited session. Do not create or resurrect a session merely to work around that message.

## Read and act

- Read a pane with `zellij --session "$session_name" action dump-screen --pane-id "$pane_id"`; add `--full` only when scrollback is needed. Use `zellij --session "$session_name" subscribe --pane-id "$pane_id" --format json` for ongoing output; it streams full viewport updates until stopped or the pane closes. Bound a subscription when running it from a tool. `list-panes --json` also reports whether a command pane exited and its exit status.
- To run a command in a new pane, use `zellij --session "$session_name" run --no-focus --cwd "$working_dir" -- command arg1 arg2`. It prints the created pane ID. `--no-focus` leaves the user's focus alone; omit it when the user wants the new pane brought forward. Add `--tab-id` for a specific tab. A command pane normally remains visible after the command exits, so use `--close-on-exit` only when that is wanted. For a new tab, use `action new-tab --name "name" --cwd "$working_dir"`; it prints the tab ID.
- When asked to navigate, use `action go-to-tab-by-id "$tab_id"` or `action focus-pane-id "$pane_id"`. Open a file in the configured editor with `zellij --session "$session_name" edit --tab-id "$tab_id" --line-number 10 file`. If the user asks for a new detached session, use `zellij attach --create-background "$session_name"`.
- To send text to a terminal program already running in a pane, use `action paste --pane-id "$pane_id" 'text'`. Paste uses bracketed paste, including for multiline text. Send a separate `action send-keys --pane-id "$pane_id" Enter` only when the program should submit that text. Use `send-keys` for control keys such as `"Ctrl c"` or `Escape`. These commands target the program in the pane, which might be an editor or REPL rather than a shell.
- Capture returned IDs and do dependent actions in order. Do not send concurrent input to the same pane. Read the result with `dump-screen`, `subscribe`, or pane exit status before deciding the next action.

Prefer commands with a pane or tab ID over actions that affect the current focus. Avoid changing the user's focus for background work. Closing panes, tabs, or sessions, interrupting processes, and submitting text inside an existing program should follow the user's requested task and the same care as doing those actions directly.

For current options and less common actions, check `zellij <command> --help` or the official [CLI overview](https://zellij.dev/documentation/controlling-zellij-through-cli), [action reference](https://zellij.dev/documentation/cli-actions.html), [run and edit guide](https://zellij.dev/documentation/zellij-run-and-edit.html), [subscribe guide](https://zellij.dev/documentation/zellij-subscribe.html), and [programmatic control guide](https://zellij.dev/documentation/programmatic-control.html).
