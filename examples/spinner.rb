# frozen_string_literal: true

# Usage: bundle exec ruby examples/spinner.rb
#
# Demonstrates Thaum::Spinner — animation frame driven by on_tick.
# Shows the default braille spinner and two custom-frame variants
# stacked side by side. Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class Label
  include Thaum::Sigil

  def initialize(text)
    @text = text
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    canvas.text(content: @text, fg: theme.dim)
  end
end

class SpinnerApp
  include Thaum::App

  def initialize
    @default = Thaum::Spinner.new # ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏
    @dots    = Thaum::Spinner.new(frames: %w[. .. ...], interval: 0.3)
    @arrow   = Thaum::Spinner.new(frames: %w[← ↖ ↑ ↗ → ↘ ↓ ↙], interval: 0.12)

    @label_a = Label.new(" default braille")
    @label_b = Label.new(" three dots")
    @label_c = Label.new(" arrow rotation")
    @hint    = Label.new(" esc to quit")
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical do
      region(height: 1) { spinner_row(spinner: @default, label: @label_a) }
      region(height: 1) { spinner_row(spinner: @dots,    label: @label_b) }
      region(height: 1) { spinner_row(spinner: @arrow,   label: @label_c) }
      region(height: :fill) { @hint }
    end
  end

  private

  def spinner_row(spinner:, label:)
    horizontal do
      region(width: 4)     { spinner }
      region(width: :fill) { label }
    end
  end
end

Thaum.run(SpinnerApp.new)
