# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestRunLoopSink < Minitest::Test
  def setup
    @dir  = Dir.mktmpdir("thaum-runloop")
    @path = File.join(@dir, "thaum.log")
  end

  def teardown
    Thaum::Log.sink = nil
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  def test_open_log_sink_returns_nil_and_leaves_sink_off_when_log_nil
    assert_nil Thaum::RunLoop.open_log_sink(nil)
    assert_nil Thaum::Log.sink
  end

  def test_open_log_sink_opens_a_file_sink_and_activates_it
    sink = Thaum::RunLoop.open_log_sink(@path)

    assert_instance_of Thaum::Log::FileSink, sink
    assert_same sink, Thaum::Log.sink
    assert File.exist?(@path), "sink should have created the file on open"
  end

  def test_open_log_sink_truncates_on_open
    File.write(@path, "stale\n")
    Thaum::RunLoop.open_log_sink(@path)
    Thaum.log.info("fresh")

    contents = File.read(@path)
    refute_match(/stale/, contents)
    assert_match(/INFO  fresh/, contents)
  end

  def test_close_log_sink_closes_and_deactivates
    sink = Thaum::RunLoop.open_log_sink(@path)
    Thaum::RunLoop.close_log_sink(sink)

    assert_nil Thaum::Log.sink
    assert_nil sink.write("after close") # closed: no raise
  end

  def test_close_log_sink_is_a_noop_when_nil
    Thaum::RunLoop.close_log_sink(nil) # must not raise
    assert_nil Thaum::Log.sink
  end
end
