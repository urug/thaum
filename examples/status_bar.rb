# frozen_string_literal: true

# Usage: bundle exec ruby examples/status_bar.rb
#
# Demonstrates Thaum::StatusBar. Three segments along the bottom:
# - "Ready"          (plain)
# - clock            (plain, updates each tick)
# - "[ Quit ]"       (clickable — exits the app)
#
# Click the Quit segment with the mouse, or press esc.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class Body
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    inner = canvas.border(fg: theme.border, style: :rounded)
    inner.text(content: " StatusBar demo", y: 1, fg: theme.fg)
    inner.text(content: " Click [ Quit ] in the bar, or press esc.", y: 3, fg: theme.info_fg)
  end
end

class StatusBarApp
  include Thaum::App

  def initialize
    @body = Body.new
    @bar  = Thaum::StatusBar.new(segments: segments)
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_key(event)
    quit if event.key == :escape
  end

  def on_tick(_event)
    new_segments = segments
    @bar.segments = new_segments
  end

  def partition
    vertical do
      region(height: :fill) { @body }
      region(height: 1)     { @bar }
    end
  end

  private

  def segments
    [
      "Ready",
      Time.now.strftime("%H:%M:%S"),
      { label: "[ Quit ]", on_click: -> { quit } }
    ]
  end
end

StatusBarApp.run
