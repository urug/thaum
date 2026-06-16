# frozen_string_literal: true

# Usage: bundle exec ruby examples/tabs.rb
#
# Demonstrates Thaum::Tabs. Four tabs along the top; ←/→ navigate, the
# content pane below switches via Tabs::ActivatedEvent. Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

PAGES = {
  "Overview" => [
    "Thaum is a Ruby TUI framework.",
    "",
    "Sigils render and handle events.",
    "Layouts partition space.",
    "Octagrams package both as composites."
  ],
  "Sigils" => [
    "Built-in sigils:",
    "",
    "  Text, TextInput, Select, Button",
    "  Table, ScrollView",
    "  Spinner, ProgressBar, Checkbox, Tabs"
  ],
  "Themes" => [
    "Eight themes ship with the framework:",
    "",
    "  Catppuccin Mocha / Latte",
    "  Gruvbox Dark, Nord, Dracula",
    "  Solarized Dark / Light, Material"
  ],
  "Keys" => [
    "Universal: Ctrl-C exits.",
    "",
    "Tab / Shift-Tab cycle focus.",
    "Bracketed paste becomes PasteEvent.",
    "Mouse support arrives in a later phase."
  ]
}.freeze

class Page
  include Thaum::Sigil

  def initialize(tabs)
    @tabs = tabs
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    inner = canvas.border(fg: theme.border, style: :rounded)
    lines = PAGES.fetch(@tabs.current)
    lines.each_with_index do |line, i|
      break if i >= inner.height

      inner.text(content: " #{line}", y: i, fg: theme.fg)
    end
  end
end

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " ←/→ switch tabs   esc quits", fg: theme.dim)
  end
end

class TabsApp
  include Thaum::App

  def initialize
    @tabs = Thaum::Tabs.new(labels: PAGES.keys)
    @page = Page.new(@tabs)
    @hint = Hint.new
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_mount
    focus(@tabs)
  end

  def on_key(event)
    quit if event.key == :escape
  end

  # Tabs::ActivatedEvent bubbles up every time the active tab changes. The
  # Page sigil reads @tabs.current on each render, so we don't need to
  # do anything with it — but acknowledging it silences the framework's
  # default "unhandled event" warning to stderr.
  def on_event(event)
    return if event.is_a?(Thaum::Tabs::ActivatedEvent)

    super
  end

  def partition
    vertical do
      region(height: 1)     { @tabs }
      region(height: :fill) { @page }
      region(height: 1)     { @hint }
    end
  end
end

Thaum.run(TabsApp.new)
