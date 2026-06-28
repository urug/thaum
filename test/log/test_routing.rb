# frozen_string_literal: true

require "test_helper"

class TestLogRouting < Minitest::Test
  class RecordingSink
    attr_reader :lines

    def initialize = @lines = []
    def open = self
    def write(line) = (@lines << line) && nil
    def close = nil
  end

  def teardown
    Thaum::Log.sink = nil
  end

  # --- Thaum.log accessor ---

  def test_log_returns_a_memoized_logger
    assert_instance_of Thaum::Log::Logger, Thaum.log
    assert_same Thaum.log, Thaum.log
  end

  def test_log_tracks_the_current_sink_dynamically
    Thaum::Log.sink = (first = RecordingSink.new)
    Thaum.log.info("one")
    Thaum::Log.sink = (second = RecordingSink.new)
    Thaum.log.info("two")

    assert_match(/INFO  one\z/, first.lines.first)
    assert_match(/INFO  two\z/, second.lines.first)
  end

  # --- warn_internal ---

  def test_warn_internal_routes_to_sink_at_given_level_when_active
    Thaum::Log.sink = (sink = RecordingSink.new)
    Thaum.warn_internal("slow frame", level: :warn)

    assert_match(/WARN  slow frame\z/, sink.lines.first)
  end

  def test_warn_internal_falls_back_to_stderr_when_no_sink
    Thaum::Log.sink = nil
    out = capture_io { Thaum.warn_internal("no sink here", level: :error) }.last
    assert_match(/no sink here/, out)
  end

  def test_warn_internal_does_not_raise_when_sink_write_fails
    broken = Object.new
    def broken.write(_) = raise("disk full")
    Thaum::Log.sink = broken

    out = capture_io { Thaum.warn_internal("recovered", level: :error) }.last
    assert_match(/recovered/, out) # fell back to stderr instead of raising
  end

  # --- safe_invoke routing ---

  def test_safe_invoke_routes_handler_exception_to_sink_at_error
    Thaum::Log.sink = (sink = RecordingSink.new)
    Thaum.safe_invoke("App#on_mount") { raise "kaboom" }

    line = sink.lines.first
    assert_match(/ERROR  unhandled exception in App#on_mount: RuntimeError: kaboom/, line)
    assert_match(/\n    /, line) # backtrace folded into the same record
  end

  def test_safe_invoke_falls_back_to_stderr_without_sink
    Thaum::Log.sink = nil
    out = capture_io { Thaum.safe_invoke("App#on_mount") { raise "kaboom" } }.last
    assert_match(/unhandled exception in App#on_mount: RuntimeError: kaboom/, out)
  end

  # --- emit-guard routing ---

  class TickSigil
    include Thaum::Sigil
  end

  class TickApp
    include Thaum::App

    attr_reader :sigil

    def initialize = @sigil = TickSigil.new
    def partition = vertical { region(height: :fill) { @sigil } }
    def on_event(_event); end
  end

  def test_emit_guard_warning_routes_to_sink_at_warn
    app = TickApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    app.wire_sigils

    Thaum::Log.sink = (sink = RecordingSink.new)
    app.sigil.emit(Thaum::TickEvent.new(time: 1.0, delta: 0.1))

    assert_match(/WARN  dropping Thaum::TickEvent/, sink.lines.first)
  end
end
