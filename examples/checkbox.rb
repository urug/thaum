# frozen_string_literal: true

# Usage: bundle exec ruby examples/checkbox.rb
#
# Demonstrates Thaum::Checkbox. Four checkboxes (one indeterminate),
# Tab between them, Space or Enter to toggle. A status line shows the
# current state. Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class Status
  include Thaum::Sigil

  def initialize(boxes)
    @boxes = boxes
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    summary = @boxes.map { |b| state(b) }.join("  ")
    canvas.text(content: " #{summary}", fg: theme.dim)
  end

  private

  def state(box)
    mark = if box.indeterminate?
             "-"
           else
             box.checked? ? "✓" : " "
           end
    "[#{mark}] #{box.instance_variable_get(:@label)}"
  end
end

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " tab next   space/enter toggles   esc quits", fg: theme.dim)
  end
end

class CheckboxApp
  include Thaum::App

  def initialize
    @ssl      = Thaum::Checkbox.new(label: "Enable SSL", checked: true)
    @notify   = Thaum::Checkbox.new(label: "Email me updates")
    @beta     = Thaum::Checkbox.new(label: "Beta features", indeterminate: true)
    @newsletter = Thaum::Checkbox.new(label: "Newsletter (twice a month)")
    @status   = Status.new([@ssl, @notify, @beta, @newsletter])
    @hint     = Hint.new
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_key(event)
    quit if event.key == :escape
  end

  # Checkbox::ChangedEvent bubbles up on every toggle. The Status sigil reads
  # each Checkbox's state at render time, so we don't need to do anything
  # — but acknowledging the event keeps stderr clean.
  def on_event(event)
    return if event.is_a?(Thaum::Checkbox::ChangedEvent)

    super
  end

  def partition
    vertical do
      region(height: 1) { @ssl }
      region(height: 1) { @notify }
      region(height: 1) { @beta }
      region(height: 1) { @newsletter }
      region(height: :fill) { @status }
      region(height: 1) { @hint }
    end
  end
end

CheckboxApp.run
