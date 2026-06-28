# frozen_string_literal: true

require "test_helper"

class TestLogger < Minitest::Test
  # A sink that records the lines handed to it, so we assert on what the
  # Logger formats without touching the filesystem.
  class RecordingSink
    attr_reader :lines

    def initialize = @lines = []
    def open = self
    def write(line) = (@lines << line) && nil
    def close = nil
  end

  def setup
    @sink = RecordingSink.new
    Thaum::Log.sink = @sink
  end

  def teardown
    Thaum::Log.sink = nil
  end

  def logger = Thaum::Log::Logger.new

  def test_info_formats_timestamp_level_and_message
    logger.info("mounted Picker")

    assert_equal 1, @sink.lines.size
    assert_match(/\A\d\d:\d\d:\d\d\.\d\d\d INFO  mounted Picker\z/, @sink.lines.first)
  end

  def test_each_level_is_uppercased_in_the_line
    log = logger
    log.debug("d")
    log.info("i")
    log.warn("w")
    log.error("e")

    levels = @sink.lines.map { |l| l.split(/\s+/)[1] }
    assert_equal %w[DEBUG INFO WARN ERROR], levels
  end

  def test_severity_methods_return_nil
    assert_nil logger.info("x")
  end

  def test_block_form_is_used_as_the_message
    logger.debug { "expensive #{2 + 2}" }
    assert_match(/DEBUG  expensive 4\z/, @sink.lines.first)
  end

  def test_block_overrides_positional_argument
    logger.info("ignored") { "from block" }
    assert_match(/INFO  from block\z/, @sink.lines.first)
  end

  # --- null-safety / laziness when no sink is active ---

  def test_no_op_when_sink_nil
    Thaum::Log.sink = nil
    assert_nil logger.info("nope")
    assert_empty @sink.lines
  end

  def test_block_not_invoked_when_sink_nil
    Thaum::Log.sink = nil
    invoked = false
    logger.debug do
      invoked = true
      "x"
    end
    refute invoked, "block must not be built when no sink is active"
  end

  # --- exception formatting ---

  def test_exception_formats_class_message_and_indented_backtrace
    error = RuntimeError.new("boom")
    error.set_backtrace(["a.rb:1:in `foo'", "b.rb:2:in `bar'"])
    logger.error(error)

    line = @sink.lines.first
    assert_match(/ERROR  RuntimeError: boom\n    a\.rb:1:in `foo'\n    b\.rb:2:in `bar'\z/, line)
  end

  def test_exception_without_backtrace_is_just_class_and_message
    logger.error(RuntimeError.new("plain"))
    assert_match(/ERROR  RuntimeError: plain\z/, @sink.lines.first)
  end
end
