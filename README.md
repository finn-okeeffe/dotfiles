# Neovim notebook and plotting support

The Neovim configuration uses `molten.nvim` to run Jupyter code and `image.nvim` to display plot output. `lazy.nvim` installs these plugins, but it does not install their system or Python dependencies.

Before using this setup, provide:

- Neovim 0.9.4 or later and Python 3.10 or later;
- a current `pynvim` tool with `jupyter_client` in the same environment (for example,
  `uv tool install --upgrade --with jupyter-client pynvim`);
- a registered Jupyter kernel, such as one provided by `ipykernel`; and
- ImageMagick, with either `magick` or the older `convert` and `identify` executables.

Neovim automatically discovers the `pynvim-python` executable installed by a current `pynvim` uv tool. The Jupyter kernel may use a separate project environment; it does not need to share Molten's Python-provider environment.

## Keymap help

Press `<Space>?` in Normal mode to open the which-key help pane. It lists the
available keymaps and their descriptions; type part of a key sequence to narrow the
list or press `<Esc>` to close it.

## Python language server and debugger

Start Neovim normally with `nvim` from a project directory or one of its children; it
does not need to be run through `uv`. For a uv project, run `uv sync` to create its
`.venv`. Pyright uses that environment's Python interpreter for the project.

To debug Python from Neovim, add `debugpy` to the project:

```sh
uv add --dev debugpy
```

Open the Python file to run, set breakpoints, then start debugging with `<Space>dc`.
Choose either the current file or a Python module when prompted. The debugger runs it
through the project environment and opens the debugger panes when execution begins.

Project-specific launch entries belong in `.nvim/dap.json` at the project root. Copy
[`nvim/templates/dap.json`](nvim/templates/dap.json) as a starting point. Neovim finds
the closest `pyproject.toml` or `.git` directory above the active file, then reads its
`.nvim/dap.json` when debugging starts. Use `${workspaceRoot}` for the launch `cwd`;
the provider replaces it with that project root. The template runs the project's
`.venv/bin/python` directly. debugpy adds its own launcher arguments to this command,
so it must be a Python executable rather than a multi-part `uv run` command.
Python debug sessions open in a new Zellij pane and close when the debugged program
exits. Start Neovim from inside Zellij before launching one.
When execution stops for an exception, Neovim shows its details in a wrapped floating
window instead of virtual text. It closes when you continue, stop, or disconnect.

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal | `<Space>db` | Toggle a breakpoint on the current line. |
| Normal | `<Space>dc` | Start or continue debugging. |
| Normal | `<Space>dn` | Step over. |
| Normal | `<Space>di` | Step into. |
| Normal | `<Space>do` | Step out. |
| Normal | `<Space>dr` | Open and jump to the debug REPL. |
| Normal | `<Space>de` | Return to the editor window used to start debugging. |
| Visual | `<Space>de` | Execute the characterwise or linewise Python selection in the debug REPL. |
| Normal | `<Space>du` | Show or hide the debugger panes and close the REPL window. |
| Normal | `<Space>dx` | Show or hide the most recent exception window while paused. |
| Normal | `<Space>dt` | Stop debugging. |

> [!NOTE]
> This setup uses a development build of Zellij that supports the Kitty graphics protocol for images, so plot rendering works inside Zellij. Do not assume the same support is available in other Zellij builds.

Initialise Molten with `:MoltenInit` (optionally followed by a kernel name), then use these mappings:

- `\mi`: initialise Molten;
- `\os`: show or enter the current cell's output;
- `\oh`: hide the current cell's output;
- `\rc`: run the current cell;
- `\ra`: run the current cell and all cells above it;
- `\rA`: run all cells;
- `\rl`: run the current line; and
- visual `\r`: run the selected range.

Text output appears as virtual text. Plot images are float-only: use `\os` to show or enter the current cell's output and `\oh` to hide it. Molten keeps the float below its cell when there is room; near the bottom of the window or the end of the document, it moves the float upwards to reserve up to the configured 20-row preview height. If the window is too short for that preview, the float starts at its minimum row and Molten limits it to the available height. Keeping image decorations out of the Quarto buffer and disabling overlap-driven redraws prevents them from interfering with entry into Neovim's Visual modes.
