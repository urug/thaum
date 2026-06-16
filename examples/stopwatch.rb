# frozen_string_literal: true

# Usage: bundle exec ruby examples/stopwatch.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class StopwatchSigil
  include Thaum::Sigil

  def initialize
    @elapsed = 0.0
    @running = false
  end

  def on_key(event)
    case event.key
    when " " then @running = !@running
    when "r" then @elapsed = 0.0
    else emit(event)
    end
  end

  def on_tick(event)
    return unless @running

    @elapsed += event.delta
    request_render
  end

  def render(canvas:, theme:)
    mid = canvas.height / 2
    canvas.fill(bg: theme.bg)
    canvas.text(content: format_time, fg: @running ? theme.accent : theme.fg, align: :center, y: mid - 1)
    hint = @running ? "space pause  r reset  t theme  esc quit" : "space start  r reset  t theme  esc quit"
    canvas.text(content: hint, fg: theme.dim, align: :center, y: mid + 1)
  end

  private

  def format_time
    minutes = (@elapsed / 60).to_i
    seconds = (@elapsed % 60).to_i
    centis  = ((@elapsed * 100) % 100).to_i
    format("%<m>02d:%<s>02d.%<c>02d", m: minutes, s: seconds, c: centis)
  end
end

class StopwatchApp
  include Thaum::App

  THEME_CYCLE = %i[catppuccin_mocha gruvbox_dark nord dracula solarized_dark catppuccin_latte].freeze

  def initialize
    @stopwatch   = StopwatchSigil.new
    @theme_index = 0
  end

  # Thaum.run reads this fresh every frame; swapping the index and requesting
  # a render is all that's needed to retheme the whole app.
  def theme = Thaum::Themes[THEME_CYCLE[@theme_index]]

  def on_key(event)
    case event.key
    when :escape then quit
    when "t" then cycle_theme
    end
  end

  def partition
    vertical do
      region(height: :fill) { @stopwatch }
    end
  end

  private

  def cycle_theme
    @theme_index = (@theme_index + 1) % THEME_CYCLE.length
    request_render
  end
end

Thaum.run(StopwatchApp.new, tick: 0.05)
