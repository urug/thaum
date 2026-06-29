# frozen_string_literal: true

# Usage: bundle exec ruby examples/scroll_view.rb
#
# Demonstrates Thaum::ScrollView. Renders a long, optionally wide buffer
# of pre-formatted text rows. Vertical and horizontal scrolling, ▲/▼
# indicators when off-viewport content exists.
#
# Keys: ↑/↓/pgup/pgdn/home/end for vertical, ←/→ for horizontal, esc to quit.
# Mouse wheel scrolls vertically.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

ROWS = (1..120).map do |n|
  num = n.to_s.rjust(3)
  case n % 5
  when 0 then "#{num}  #{'─' * 90}"
  when 1 then "#{num}  the quick brown fox jumps over the lazy dog #{n} times"
  when 2 then "#{num}  ねこは魚を食べる — wide chars stay aligned because ScrollView slices by display column"
  when 3 then "#{num}  far-right column reachable only by horizontal scrolling →→→→→→→→→ here: #{n * 7}"
  else        "#{num}  short row"
  end
end.freeze

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(
      content: " ↑/↓ or wheel scroll   pgup/pgdn page   ←/→ horizontal   home/end edges   esc quits",
      fg: theme.dim
    )
  end
end

class ScrollViewApp
  include Thaum::App

  def initialize
    @view = Thaum::ScrollView.new(rows: ROWS)
    @hint = Hint.new
  end

  def on_mount
    focus(@view)
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical do
      region(height: :fill) { @view }
      region(height: 1)     { @hint }
    end
  end
end

ScrollViewApp.run
