# frozen_string_literal: true

# Usage: bundle exec ruby examples/select.rb
#
# Demonstrates Thaum::Select. Up/down to navigate, Enter to pick.
# The chosen item is printed after the app exits.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

FRUITS = %w[
  apricot banana cherry date elderberry fig grape honeydew
  imbe jujube kiwi lemon mango nectarine orange papaya
  quince raspberry strawberry tangerine ugni vanilla watermelon
].freeze

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " ↑/↓ navigate   enter picks   esc quits", fg: theme.info_fg)
  end
end

class SelectApp
  include Thaum::App

  attr_reader :result

  def initialize
    @select = Thaum::Select.new(items: FRUITS)
    @hint   = Hint.new
    @result = nil
  end

  def on_mount
    focus(@select)
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def on_event(event)
    return unless event.is_a?(Thaum::Select::SelectedEvent)

    @result = event.item
    quit
  end

  def partition
    vertical do
      region(height: :fill) { @select }
      region(height: 1)     { @hint }
    end
  end
end

app = SelectApp.new
Thaum.run(app)
puts app.result if app.result
