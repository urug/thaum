# frozen_string_literal: true

require "concurrent"
require "unicode/display_width/string_ext"

require_relative "thaum/version"
require_relative "thaum/rendering/style"
require_relative "thaum/rendering/cell"
require_relative "thaum/rect"
require_relative "thaum/rendering/box_drawing"
require_relative "thaum/rendering/buffer"
require_relative "thaum/rendering/canvas"
require_relative "thaum/seq"
require_relative "thaum/color"
require_relative "thaum/terminal"
require_relative "thaum/event"
require_relative "thaum/key_event"
require_relative "thaum/events"
require_relative "thaum/keys"
require_relative "thaum/escape_parser"
require_relative "thaum/input_reader"
require_relative "thaum/rendering/renderer"
require_relative "thaum/themes"
require_relative "thaum/log/sink"
require_relative "thaum/log/file_sink"
require_relative "thaum/log/logger"
require_relative "thaum/sigil"
require_relative "thaum/layout"
require_relative "thaum/octagram"
require_relative "thaum/concerns/focus"
require_relative "thaum/concerns/context_update"
require_relative "thaum/concerns/modal"
require_relative "thaum/concerns/tab_navigation"
require_relative "thaum/app"
require_relative "thaum/action"
require_relative "thaum/tree"
require_relative "thaum/hit_test"
require_relative "thaum/painter"
require_relative "thaum/dispatch"
require_relative "thaum/run_loop"
require_relative "thaum/sigils/text"
require_relative "thaum/sigils/text_input"
require_relative "thaum/sigils/select"
require_relative "thaum/sigils/button"
require_relative "thaum/sigils/scroll_view"
require_relative "thaum/sigils/table"
require_relative "thaum/sigils/spinner"
require_relative "thaum/sigils/progress_bar"
require_relative "thaum/sigils/checkbox"
require_relative "thaum/sigils/status_bar"
require_relative "thaum/sigils/tabs"

module Thaum
  class Error < StandardError; end
  class LayoutError < Error; end
  class EmitFromUpdateError < Error; end
  class FocusOrderError < Error; end

  # The logger `Thaum.log` returns — memoized, reads the active sink per call
  # so it tracks the per-run sink set by the run loop. No-op when no sink.
  def self.log
    @log ||= Log::Logger.new
  end

  # Route a framework-internal warning. When a sink is open it goes to the log
  # file at the given level (so the companion reader colorizes it like any
  # other line); otherwise it falls back to stderr. Never raises — a failing
  # sink write must not defeat safe_invoke's keep-the-terminal-sane contract.
  def self.warn_internal(message, level:)
    if Log.sink
      begin
        log.public_send(level, message)
        return
      rescue StandardError
        # Sink write failed — fall through to stderr.
      end
    end
    warn "[Thaum] #{message}"
  end

  # Invoke a handler, rescuing any exception so a bug in user code can't
  # leave the terminal in raw mode + alt screen. Routes class, message, and
  # backtrace through warn_internal (log file when active, else stderr).
  def self.safe_invoke(label)
    yield
  rescue StandardError => e
    warn_internal("unhandled exception in #{label}: #{Log.format_exception(e)}", level: :error)
    nil
  end

  # Startup entry point. Blocks until app.quit is called. Returns nil.
  def self.run(app, tick: 0.1, threads: 4, log: nil)
    RunLoop.run(app:, tick:, threads:, log:)
  end
end
