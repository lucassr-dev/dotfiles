-- WezTerm Configuration
-- Catppuccin Mocha Theme + JetBrainsMono Nerd Font

local wezterm = require 'wezterm'
local config = {}

-- Use config builder if available (WezTerm 20220807+)
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- ===== APPEARANCE =====

-- Color scheme: Catppuccin Mocha
config.color_scheme = 'Catppuccin Mocha'

-- Font configuration
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Symbols Nerd Font',
}
config.font_size = 13.0
config.line_height = 1.0
config.cell_width = 1.0

-- Harfbuzz features (optional ligatures)
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

-- Window appearance
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.text_background_opacity = 1.0
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Cursor
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 800
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

-- Scrollback
config.scrollback_lines = 10000

-- ===== TAB BAR =====

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.tab_max_width = 32

-- Catppuccin Mocha colors for tab bar
local catppuccin_mocha = {
  rosewater = "#f5e0dc",
  flamingo = "#f2cdcd",
  pink = "#f5c2e7",
  mauve = "#cba6f7",
  red = "#f38ba8",
  maroon = "#eba0ac",
  peach = "#fab387",
  yellow = "#f9e2af",
  green = "#a6e3a1",
  teal = "#94e2d5",
  sky = "#89dceb",
  sapphire = "#74c7ec",
  blue = "#89b4fa",
  lavender = "#b4befe",
  text = "#cdd6f4",
  subtext1 = "#bac2de",
  subtext0 = "#a6adc8",
  overlay2 = "#9399b2",
  overlay1 = "#7f849c",
  overlay0 = "#6c7086",
  surface2 = "#585b70",
  surface1 = "#45475a",
  surface0 = "#313244",
  base = "#1e1e2e",
  mantle = "#181825",
  crust = "#11111b",
}

config.colors = {
  tab_bar = {
    background = catppuccin_mocha.crust,
    active_tab = {
      bg_color = catppuccin_mocha.blue,
      fg_color = catppuccin_mocha.base,
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = catppuccin_mocha.surface0,
      fg_color = catppuccin_mocha.text,
    },
    inactive_tab_hover = {
      bg_color = catppuccin_mocha.surface1,
      fg_color = catppuccin_mocha.text,
    },
    new_tab = {
      bg_color = catppuccin_mocha.surface0,
      fg_color = catppuccin_mocha.text,
    },
    new_tab_hover = {
      bg_color = catppuccin_mocha.surface1,
      fg_color = catppuccin_mocha.text,
    },
  },
}

-- Custom tab bar formatter
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local background = catppuccin_mocha.surface0
  local foreground = catppuccin_mocha.text

  if tab.is_active then
    background = catppuccin_mocha.blue
    foreground = catppuccin_mocha.base
  elseif hover then
    background = catppuccin_mocha.surface1
    foreground = catppuccin_mocha.text
  end

  local title = tab.active_pane.title
  -- Ensure tab is not longer than max_width
  if #title > max_width - 4 then
    title = wezterm.truncate_right(title, max_width - 4) .. '…'
  end

  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = ' ' .. (tab.tab_index + 1) .. ': ' .. title .. ' ' },
  }
end)

-- ===== PERFORMANCE =====

config.max_fps = 60
config.animation_fps = 60
config.front_end = "WebGpu"

-- ===== KEYBINDINGS =====

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  -- Tab management
  { key = 't', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentTab { confirm = true } },
  { key = 'Tab', mods = 'CTRL', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },

  -- Tab navigation by number
  { key = '1', mods = 'ALT', action = wezterm.action.ActivateTab(0) },
  { key = '2', mods = 'ALT', action = wezterm.action.ActivateTab(1) },
  { key = '3', mods = 'ALT', action = wezterm.action.ActivateTab(2) },
  { key = '4', mods = 'ALT', action = wezterm.action.ActivateTab(3) },
  { key = '5', mods = 'ALT', action = wezterm.action.ActivateTab(4) },
  { key = '6', mods = 'ALT', action = wezterm.action.ActivateTab(5) },
  { key = '7', mods = 'ALT', action = wezterm.action.ActivateTab(6) },
  { key = '8', mods = 'ALT', action = wezterm.action.ActivateTab(7) },
  { key = '9', mods = 'ALT', action = wezterm.action.ActivateTab(8) },

  -- Pane splitting
  { key = '"', mods = 'LEADER|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '%', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'x', mods = 'LEADER', action = wezterm.action.CloseCurrentPane { confirm = true } },
  { key = 'z', mods = 'LEADER', action = wezterm.action.TogglePaneZoomState },

  -- Pane navigation (vim-like)
  { key = 'h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },

  -- Pane resizing
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },

  -- Copy/Paste
  { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },

  -- Font size
  { key = '=', mods = 'CTRL', action = wezterm.action.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = wezterm.action.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = wezterm.action.ResetFontSize },

  -- Scrollback
  { key = 'PageUp', mods = 'SHIFT', action = wezterm.action.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = wezterm.action.ScrollByPage(1) },
  { key = 'Home', mods = 'SHIFT', action = wezterm.action.ScrollToTop },
  { key = 'End', mods = 'SHIFT', action = wezterm.action.ScrollToBottom },

  -- Quick select (URL, paths, hashes)
  { key = 'Space', mods = 'LEADER', action = wezterm.action.QuickSelect },

  -- Search
  { key = 'f', mods = 'CTRL|SHIFT', action = wezterm.action.Search 'CurrentSelectionOrEmptyString' },

  -- Launcher menu
  { key = 'l', mods = 'LEADER', action = wezterm.action.ShowLauncher },

  -- Command palette
  { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette },
}

-- ===== MOUSE BINDINGS =====

config.mouse_bindings = {
  -- Right click to paste
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Ctrl+Click to open URLs
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- ===== HYPERLINKS =====

config.hyperlink_rules = {
  -- URLs
  {
    regex = '\\b\\w+://[\\w.-]+\\.[a-z]{2,15}\\S*\\b',
    format = '$0',
  },
  -- Email addresses
  {
    regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',
    format = 'mailto:$0',
  },
  -- File paths
  {
    regex = [[["]?([\w\d]{1}[\w\d\.\-_/~:]+)["]?]],
    format = '$1',
  },
}

-- ===== LAUNCH MENU =====

config.launch_menu = {
  {
    label = 'Bash',
    args = { 'bash', '-l' },
  },
  {
    label = 'Zsh',
    args = { 'zsh', '-l' },
  },
  {
    label = 'Fish',
    args = { 'fish', '-l' },
  },
  {
    label = 'Nushell',
    args = { 'nu' },
  },
}

-- ===== MISC =====

-- Automatically reload config
config.automatically_reload_config = true

-- Exit behavior
config.exit_behavior = 'Close'

-- Disable update check
config.check_for_updates = false

-- Window close confirmation
config.window_close_confirmation = 'NeverPrompt'

-- Inactive pane brightness
config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.7,
}

return config