local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local config = wezterm.config_builder()

wezterm.on('toggle-background', function(window, pane)
    local overrides = window.get_config_overrides() or {}
    if not overrides.window_backgroud_image then
        overrides.window_backgroud_image = "/home/finnokeeffe/git/dotfiles/wezterm/assets/gruvbox-wallpaper-cave.png"

        overrides.window_backgroud_image = nil
    end
    window:set_config_overrides(overrides)
end)

-- Font settings
config.font_size = 16
config.font = wezterm.font("FiraCode Nerd Font Mono")

-- Colors
config.color_scheme = 'GruvboxDarkHard'

-- keybinds
config.leader = {
    key="j",
    mods="CTRL",
    timeout_milliseconds=500
}
config.keys = {
    {
        key="R",
        mods="LEADER",
        action=wezterm.action.ReloadConfiguration,
    },
    {
        key="b",
        mods="CTRL",
        action = wezterm.action.EmitEvent 'toggle-background',
    },
    {
        key="_",
        mods="ALT|SHIFT",
        action=wezterm.action.SplitPane {
            direction="Down"
        }
    },
    {
        key="+",
        mods="ALT|SHIFT",
        action=wezterm.action.SplitPane {
            direction="Right"
        }
    },
    {
        key="UpArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Up", 1
        }
    },
    {
        key="DownArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Down", 1
        }
    },
    {
        key="RightArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Right", 1
        }
    },
    {
        key="LeftArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Left", 1
        }
    },
    {
        key="LeftArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Left",
    },
    {
        key="RightArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Right",
    },
    {
        key="UpArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Up",
    },
    {
        key="DownArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Down",
    },
    {
        key="w",
        mods="CTRL",
        action = wezterm.action.CloseCurrentPane { confirm = true},
    },
    {
        key="UpArrow",
        mods="CTRL|SHIFT",
        action=wezterm.action.ScrollByLine(-1),
    },
    {
        key="DownArrow",
        mods="CTRL|SHIFT",
        action=wezterm.action.ScrollByLine(1),
    },
    {
        key="F11",
        action=wezterm.action.ToggleFullScreen,
    },
    {
        key = "w",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
          end),
    },
    {
        key = "W",
        mods = "ALT",
        action = resurrect.window_state.save_window_action(),
    },
    {
        key = "T",
        mods = "ALT",
        action = resurrect.tab_state.save_tab_action(),
    },
    {
        key = "s",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.window_state.save_window_action()
        end),
    },
    { -- loading states with fuzzy find
        key = "r",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$") -- match after '/'
                id = string.match(id, "(.+)%..+$") -- remove file extention
                local opts = {
                    relative = true,
                    restore_text = true,
                    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end),
    },
}
-- Remove top bars
config.window_decorations = "RESIZE" -- disable title bar
config.hide_tab_bar_if_only_one_tab = true


-- =========================
-- Windows specific settings
-- =========================

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    -- Launch in powershell
    config.default_prog = {'powershell.exe'}
end



return config
