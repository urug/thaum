# frozen_string_literal: true

# Usage: bundle exec ruby examples/mouse.rb
#
# Click in either pane to bump its counter. Scroll wheel anywhere bumps
# the global tally. Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class ClickPane
  include Thaum::Sigil

  attr_reader :clicks

  def initialize(label)
    @label  = label
    @clicks = 0
  end

  def on_mouse(event)
    case event.action
    when :press then @clicks += 1
    end
  end

  def render(canvas:, theme:)
    canvas.fill(bg: focused? ? theme.pressed : theme.bg)
    center = canvas.height / 2
    canvas.text(content: @label, fg: theme.fg, align: :center, y: center - 1)
    canvas.text(content: "clicks: #{@clicks}", fg: theme.fg, align: :center, y: center + 1)
  end
end

class MouseApp
  include Thaum::App

  def initialize
    @left    = ClickPane.new("LEFT")
    @right   = ClickPane.new("RIGHT")
    @scrolls = 0
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def on_mouse(event)
    @scrolls += 1 if event.action == :scroll
  end

  def partition
    horizontal do
      region(width: :fill) { @left }
      region(width: :fill) { @right }
    end
  end
end

MouseApp.run
