# Neovim notebook and plotting support

The Neovim configuration uses `molten.nvim` to run Jupyter code and `image.nvim` to display plot output. `lazy.nvim` installs these plugins, but it does not install their system or Python dependencies.

Before using this setup, provide:

- Neovim 0.9.4 or later and Python 3.10 or later;
- a current `pynvim` tool with `jupyter_client` in the same environment (for example,
  `uv tool install --upgrade --with jupyter-client pynvim`);
- a registered Jupyter kernel, such as one provided by `ipykernel`; and
- ImageMagick, with either `magick` or the older `convert` and `identify` executables.

Neovim automatically discovers the `pynvim-python` executable installed by a current `pynvim` uv tool. The Jupyter kernel may use a separate project environment; it does not need to share Molten's Python-provider environment.

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

Text output appears as virtual text. Plot images are float-only: use `\os` to show or enter the current cell's output and `\oh` to hide it. Keeping image decorations out of the Quarto buffer and disabling overlap-driven redraws prevents them from interfering with entry into Neovim's Visual modes.
