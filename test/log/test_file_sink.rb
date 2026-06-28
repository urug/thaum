# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestFileSink < Minitest::Test
  def setup
    @dir  = Dir.mktmpdir("thaum-log")
    @path = File.join(@dir, "thaum.log")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  def test_write_appends_line_verbatim_with_newline
    sink = Thaum::Log::FileSink.new(@path)
    sink.open
    sink.write("12:00:00.000 INFO  hello")
    sink.close

    assert_equal "12:00:00.000 INFO  hello\n", File.read(@path)
  end

  def test_open_truncates_existing_file
    File.write(@path, "stale from a previous run\n")
    sink = Thaum::Log::FileSink.new(@path)
    sink.open
    sink.write("fresh")
    sink.close

    assert_equal "fresh\n", File.read(@path)
  end

  def test_concurrent_writes_produce_intact_lines
    sink = Thaum::Log::FileSink.new(@path)
    sink.open
    threads = 8.times.map do |t|
      Thread.new { 50.times { |i| sink.write("thread-#{t}-line-#{i}-#{'x' * 40}") } }
    end
    threads.each(&:join)
    sink.close

    lines = File.readlines(@path, chomp: true)
    assert_equal 400, lines.size
    # Every line is whole — no interleaving corrupted a record.
    assert(lines.all? { |l| l.match?(/\Athread-\d-line-\d+-x{40}\z/) })
  end

  def test_write_after_close_is_a_noop
    sink = Thaum::Log::FileSink.new(@path)
    sink.open
    sink.close
    assert_nil sink.write("after close") # does not raise
    assert_equal "", File.read(@path)
  end
end
