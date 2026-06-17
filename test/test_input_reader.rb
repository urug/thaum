# frozen_string_literal: true

require "test_helper"

class TestInputReader < Minitest::Test
  # Delivers predefined byte chunks, then raises EOFError.
  # wait_readable returns true iff more chunks remain (simulates data ready / timeout).
  class FakeIO
    def initialize(*chunks)
      @chunks = chunks.dup
      @mutex = Mutex.new
    end

    def readpartial(_n)
      @mutex.synchronize do
        raise EOFError if @chunks.empty?

        @chunks.shift
      end
    end

    def wait_readable(_timeout)
      @mutex.synchronize { !@chunks.empty? }
    end
  end

  def setup
    @queue = Thread::Queue.new
  end

  def teardown
    @reader&.stop
  end

  # Drain the queue after the reader thread has finished.
  def drain
    events = []
    events << @queue.pop until @queue.empty?
    events
  end

  def test_pushes_event_for_printable_char
    @reader = Thaum::InputReader.new(input: FakeIO.new("a"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: "a")], drain
  end

  def test_pushes_multiple_events_from_one_chunk
    @reader = Thaum::InputReader.new(input: FakeIO.new("hi"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: "h"), Thaum::KeyEvent.new(key: "i")], drain
  end

  def test_escape_sequence_in_single_chunk
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e[A"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: :up)], drain
  end

  def test_bare_escape_when_wait_readable_times_out
    # FakeIO has no more chunks after "\e", so wait_readable returns false → bare escape
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: :escape)], drain
  end

  def test_escape_sequence_split_across_chunks
    # "\e" arrives first; wait_readable returns true; "[A" arrives next
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e", "[A"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: :up)], drain
  end

  def test_multiple_chunks_produce_events_in_order
    @reader = Thaum::InputReader.new(input: FakeIO.new("a", "b", "c"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [
      Thaum::KeyEvent.new(key: "a"),
      Thaum::KeyEvent.new(key: "b"),
      Thaum::KeyEvent.new(key: "c")
    ], drain
  end

  def test_stop_joins_thread
    @reader = Thaum::InputReader.new(input: FakeIO.new("x"), queue: @queue)
    @reader.start
    @reader.stop
    refute @reader.alive?
  end

  def test_stop_returns_quickly_when_blocked_on_read
    # Reader thread blocks in readpartial on an empty pipe with no incoming data.
    # stop must interrupt the blocked read rather than wait out the join timeout.
    read_io, write_io = IO.pipe
    @reader = Thaum::InputReader.new(input: read_io, queue: @queue)
    @reader.start
    sleep 0.05 # let the thread enter the blocking read

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @reader.stop
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 0.2, "stop should return quickly, took #{elapsed}s"
    refute @reader.alive?
  ensure
    read_io&.close
    write_io&.close
  end

  def test_bracketed_paste_split_across_chunks_emits_one_event
    # "\e[200~hel" in chunk 1, "lo\e[201~" in chunk 2 — the stateful parser
    # must accumulate across reads and emit one PasteEvent at the end.
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e[200~hel", "lo\e[201~"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::PasteEvent.new(text: "hello")], drain
  end
end
