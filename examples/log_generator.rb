# frozen_string_literal: true

# Dev log console — the generator half.
#
# Usage:
#   1. In one terminal:   bundle exec ruby examples/log_reader.rb thaum.log
#   2. In another:        bundle exec ruby examples/log_generator.rb thaum.log
#
# Watch this app's log lines appear live in the reader. Both default to
# "thaum.log" in the working dir, so they pair up with no arguments.
#
# Keys:  d/i/w/e  emit a debug/info/warn/error line
#        x        raise inside a handler (shows framework-warning routing → ERROR)
#        space    emit on every tick (toggle)   esc  quit

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

# The whole UI is one sigil so the renderer actually draws it (the Painter
# walks the sigil tree; an App has no render hook of its own). It also drives
# the logging on keypress/tick.
class GeneratorPanel
  include Thaum::Sigil

  def initialize
    @auto  = false
    @count = 0
  end

  def on_key(event)
    case event.key
    when "d" then logged { Thaum.log.debug("debug ##{@count}") }
    when "i" then logged { Thaum.log.info("info ##{@count}") }
    when "w" then logged { Thaum.log.warn("warn ##{@count} — something looks slow") }
    when "e" then logged { Thaum.log.error(RuntimeError.new("manual error ##{@count}")) }
    when "x" then boom # raises; safe_invoke routes it to the log at ERROR
    when " " then (@auto = !@auto) && request_render
    else emit(event) # esc bubbles to the app, which quits
    end
  end

  def on_tick(_event)
    logged { Thaum.log.info("tick ##{@count}") } if @auto
  end

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    inner = canvas.border(fg: theme.border, style: :rounded)
    inner.text(content: " Log generator", y: 1, fg: theme.accent)
    inner.text(content: " d/i/w/e emit · x raise · space auto=#{@auto} · esc quit", y: 3, fg: theme.fg)
    inner.text(content: " emitted: #{@count}", y: 5, fg: theme.info_fg)
    inner.text(content: " (run log_reader.rb with the same path to watch)", y: 7, fg: theme.dim)
  end

  private

  # Count the emit, then re-render so the panel reflects it.
  def logged
    @count += 1
    yield
    request_render
  end

  def boom = raise("kaboom from a key handler")
end

class LogGeneratorApp
  include Thaum::App

  def initialize
    @panel = GeneratorPanel.new
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical { region(height: :fill) { @panel } }
  end
end

LogGeneratorApp.run(log: ARGV[0] || "thaum.log") if __FILE__ == $PROGRAM_NAME
