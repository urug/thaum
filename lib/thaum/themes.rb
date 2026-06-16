# frozen_string_literal: true

module Thaum
  Theme = Data.define(
    :bg, :fg, :accent, :border, :dim,
    :selection, :selection_fg, :pressed,
    :input_bg, :bar_bg,
    :success_fg, :warning_fg, :error_fg, :info_fg,
    :muted_fg, :disabled_fg
  ) do
    # New semantic fields are optional to keep existing Theme.new callers
    # working. Defaults are chosen to be safe and legible.
    def initialize(
      bg:, fg:, accent:, border:, dim:,
      selection:, selection_fg:, pressed:,
      input_bg:, bar_bg:,
      success_fg: nil, warning_fg: nil, error_fg: nil, info_fg: nil,
      muted_fg: nil, disabled_fg: nil
    )
      success_fg  ||= accent
      warning_fg  ||= accent
      error_fg    ||= accent
      info_fg     ||= accent
      muted_fg    ||= dim
      disabled_fg ||= dim

      super
    end
  end

  module Themes
    CATPPUCCIN_MOCHA = Theme.new(
      bg:           "#1e1e2e",
      fg:           "#cdd6f4",
      accent:       "#89b4fa",
      border:       "#45475a",
      dim:          "#585b70",
      selection:    "#313244",
      selection_fg: "#cdd6f4",
      pressed:      "#181825",
      input_bg:     "#181825",
      bar_bg:       "#11111b",
      success_fg:   "#a6e3a1",
      warning_fg:   "#f9e2af",
      error_fg:     "#f38ba8",
      info_fg:      "#89dceb",
      muted_fg:     "#7f849c",
      disabled_fg:  "#6c7086"
    )

    CATPPUCCIN_LATTE = Theme.new(
      bg:           "#eff1f5",
      fg:           "#4c4f69",
      accent:       "#1e66f5",
      border:       "#bcc0cc",
      dim:          "#acb0be",
      selection:    "#ccd0da",
      selection_fg: "#4c4f69",
      pressed:      "#dce0e8",
      input_bg:     "#e6e9ef",
      bar_bg:       "#dce0e8",
      success_fg:   "#40a02b",
      warning_fg:   "#df8e1d",
      error_fg:     "#d20f39",
      info_fg:      "#209fb5",
      muted_fg:     "#8c8fa1",
      disabled_fg:  "#9ca0b0"
    )

    GRUVBOX_DARK = Theme.new(
      bg:           "#282828",
      fg:           "#ebdbb2",
      accent:       "#fabd2f",
      border:       "#504945",
      dim:          "#7c6f64",
      selection:    "#3c3836",
      selection_fg: "#ebdbb2",
      pressed:      "#1d2021",
      input_bg:     "#1d2021",
      bar_bg:       "#1d2021",
      success_fg:   "#b8bb26",
      warning_fg:   "#fabd2f",
      error_fg:     "#fb4934",
      info_fg:      "#83a598",
      muted_fg:     "#a89984",
      disabled_fg:  "#7c6f64"
    )

    NORD = Theme.new(
      bg:           "#2e3440",
      fg:           "#d8dee9",
      accent:       "#88c0d0",
      border:       "#3b4252",
      dim:          "#4c566a",
      selection:    "#434c5e",
      selection_fg: "#eceff4",
      pressed:      "#242933",
      input_bg:     "#3b4252",
      bar_bg:       "#242933",
      success_fg:   "#a3be8c",
      warning_fg:   "#ebcb8b",
      error_fg:     "#bf616a",
      info_fg:      "#88c0d0",
      muted_fg:     "#81a1c1",
      disabled_fg:  "#616e88"
    )

    DRACULA = Theme.new(
      bg:           "#282a36",
      fg:           "#f8f8f2",
      accent:       "#bd93f9",
      border:       "#44475a",
      dim:          "#6272a4",
      selection:    "#44475a",
      selection_fg: "#f8f8f2",
      pressed:      "#21222c",
      input_bg:     "#21222c",
      bar_bg:       "#191a21",
      success_fg:   "#50fa7b",
      warning_fg:   "#f1fa8c",
      error_fg:     "#ff5555",
      info_fg:      "#8be9fd",
      muted_fg:     "#6272a4",
      disabled_fg:  "#6272a4"
    )

    SOLARIZED_DARK = Theme.new(
      bg:           "#002b36",
      fg:           "#839496",
      accent:       "#268bd2",
      border:       "#073642",
      dim:          "#586e75",
      selection:    "#073642",
      selection_fg: "#93a1a1",
      pressed:      "#001f27",
      input_bg:     "#073642",
      bar_bg:       "#001f27",
      success_fg:   "#859900",
      warning_fg:   "#b58900",
      error_fg:     "#dc322f",
      info_fg:      "#2aa198",
      muted_fg:     "#657b83",
      disabled_fg:  "#586e75"
    )

    SOLARIZED_LIGHT = Theme.new(
      bg:           "#fdf6e3",
      fg:           "#657b83",
      accent:       "#268bd2",
      border:       "#eee8d5",
      dim:          "#93a1a1",
      selection:    "#eee8d5",
      selection_fg: "#586e75",
      pressed:      "#ddd6c1",
      input_bg:     "#eee8d5",
      bar_bg:       "#ddd6c1",
      success_fg:   "#859900",
      warning_fg:   "#b58900",
      error_fg:     "#dc322f",
      info_fg:      "#2aa198",
      muted_fg:     "#93a1a1",
      disabled_fg:  "#93a1a1"
    )

    MATERIAL = Theme.new(
      bg:           "#263238",
      fg:           "#eeffff",
      accent:       "#82aaff",
      border:       "#314549",
      dim:          "#546e7a",
      selection:    "#314549",
      selection_fg: "#eeffff",
      pressed:      "#1e272c",
      input_bg:     "#1e272c",
      bar_bg:       "#1e272c",
      success_fg:   "#c3e88d",
      warning_fg:   "#ffcb6b",
      error_fg:     "#f07178",
      info_fg:      "#89ddff",
      muted_fg:     "#78909c",
      disabled_fg:  "#607d8b"
    )

    BY_NAME = {
      catppuccin_mocha: CATPPUCCIN_MOCHA,
      catppuccin_latte: CATPPUCCIN_LATTE,
      gruvbox_dark:     GRUVBOX_DARK,
      nord:             NORD,
      dracula:          DRACULA,
      solarized_dark:   SOLARIZED_DARK,
      solarized_light:  SOLARIZED_LIGHT,
      material:         MATERIAL
    }.freeze

    REQUIRED_KEYS = Theme.members.freeze

    CONTRAST_RULES = [
      [:fg, :bg, 4.0],
      [:selection_fg, :selection, 4.3],
      [:accent, :bg, 2.5],
      [:muted_fg, :bg, 2.0],
      [:disabled_fg, :bg, 1.5]
    ].freeze

    DEFAULT = CATPPUCCIN_MOCHA

    def self.validate_all!
      BY_NAME.each { |name, theme| validate_theme!(name: name, theme: theme) }
      true
    end

    def self.[](name)
      BY_NAME.fetch(name) do
        raise ArgumentError, "unknown theme #{name.inspect} (known: #{BY_NAME.keys.join(", ")})"
      end
    end

    def self.names = BY_NAME.keys

    def self.validate_theme!(name:, theme:)
      missing = REQUIRED_KEYS.select { |key| theme.public_send(key).nil? }
      raise ArgumentError, "theme #{name} is missing keys: #{missing.join(', ')}" unless missing.empty?

      CONTRAST_RULES.each do |fg_key, bg_key, min|
        fg = theme.public_send(fg_key)
        bg = theme.public_send(bg_key)
        next unless hex_color?(fg) && hex_color?(bg)

        ratio = contrast_ratio(hex_a: fg, hex_b: bg)
        next if ratio >= min

        raise ArgumentError,
              format("theme %s contrast too low for %s/%s: %.2f < %.1f", name, fg_key, bg_key, ratio, min)
      end

      true
    end

    def self.hex_color?(value)
      value.is_a?(String) && /\A#[0-9a-fA-F]{6}\z/.match?(value)
    end

    def self.contrast_ratio(hex_a:, hex_b:)
      l1 = relative_luminance(hex_a)
      l2 = relative_luminance(hex_b)
      hi = [l1, l2].max
      lo = [l1, l2].min
      (hi + 0.05) / (lo + 0.05)
    end

    def self.relative_luminance(hex)
      r = hex[1, 2].to_i(16) / 255.0
      g = hex[3, 2].to_i(16) / 255.0
      b = hex[5, 2].to_i(16) / 255.0

      # WCAG sRGB transform
      rs = r <= 0.03928 ? (r / 12.92) : (((r + 0.055) / 1.055)**2.4)
      gs = g <= 0.03928 ? (g / 12.92) : (((g + 0.055) / 1.055)**2.4)
      bs = b <= 0.03928 ? (b / 12.92) : (((b + 0.055) / 1.055)**2.4)
      (0.2126 * rs) + (0.7152 * gs) + (0.0722 * bs)
    end

    private_class_method :validate_theme!, :hex_color?, :contrast_ratio, :relative_luminance

    validate_all!
  end
end
