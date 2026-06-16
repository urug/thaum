# frozen_string_literal: true

# Usage: bundle exec ruby examples/progress_bar.rb
#
# Demonstrates Thaum::ProgressBar in both modes:
# - Top bar: determinate, auto-fills from 0 to 1.0 over ~5s; resets at 100%
# - Bottom bar: indeterminate, a fixed-width block walks across forever
#
# Press esc to quit, r to reset the determinate bar.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class Driver
  include Thaum::Sigil

  def initialize(bar:, interval: 0.1, step: 0.01)
    @bar      = bar
    @interval = interval
    @step     = step
    @elapsed  = 0.0
  end

  def focusable? = false

  def on_tick(event)
    @elapsed += event.delta
    advanced = false
    while @elapsed >= @interval
      @elapsed -= @interval
      @bar.value = (@bar.value + @step) > 1.0 ? 0.0 : @bar.value + @step
      advanced = true
    end
    request_render if advanced
  end

  def render(canvas:, theme:); end
end

class Label
  include Thaum::Sigil

  def initialize(text:, semantic_fg: nil)
    @text = text
    @semantic_fg = semantic_fg
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    fg = @semantic_fg ? theme.send(@semantic_fg) : theme.dim
    canvas.text(content: @text, fg: fg)
  end
end

class ProgressApp
  include Thaum::App

  def initialize
    @determinate   = Thaum::ProgressBar.new(value: 0.0)
    @indeterminate = Thaum::ProgressBar.new(indeterminate: true)
    @driver        = Driver.new(bar: @determinate)
    @det_label     = Label.new(text: " determinate (auto-fills, resets at 100%)", semantic_fg: :info_fg)
    @indet_label   = Label.new(text: " indeterminate (always animating)", semantic_fg: :muted_fg)
    @hint          = Label.new(text: " esc to quit   r to reset determinate bar", semantic_fg: :dim)
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_key(event)
    case event.key
    when :escape then quit
    when "r" then @determinate.value = 0.0
    end
  end

  def partition
    vertical do
      region(height: 1) { @det_label }
      region(height: 1) { @determinate }
      region(height: 1) { @indet_label }
      region(height: 1) { @indeterminate }
      region(height: :fill) { @hint }
      region(height: 0) { @driver } # off-screen ticker (height: 0 → no render)
    end
  end
end

Thaum.run(ProgressApp.new)
