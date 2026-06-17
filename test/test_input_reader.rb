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

  def test_csi_sequence_split_mid_body_across_chunks_emits_one_event
    # The chunk boundary falls inside the CSI body: "\e[1;5" then "H".
    # Without coalescing, the parser would see an incomplete CSI (stray
    # :escape) followed by mis-parsed ground keys. read_chunk must extend
    # the read because the first chunk ends mid-sequence.
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e[1;5", "H"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: :home, ctrl: true)], drain
  end

  def test_ss3_sequence_split_across_chunks_emits_one_event
    # "\eO" then "P" — SS3 needs one more byte after \eO to terminate.
    @reader = Thaum::InputReader.new(input: FakeIO.new("\eO", "P"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::KeyEvent.new(key: :f1)], drain
  end

  def test_sgr_mouse_sequence_split_across_chunks_emits_one_event
    # "\e[<0;10;5" then "M" — SGR mouse terminates on M/m.
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e[<0;10;5", "M"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal(
      [Thaum::MouseEvent.new(button: :left, action: :press, abs_x: 9, abs_y: 4)],
      drain
    )
  end

  def test_real_pipe_csi_split_across_reads_emits_one_event
    # Real IO.pipe: write the head of a CSI sequence, let the reader consume
    # it and start its extend-wait, then deliver the final byte. The reader
    # must coalesce them into a single KeyEvent rather than :escape + garbage.
    r, w = IO.pipe
    @reader = Thaum::InputReader.new(input: r, queue: @queue)
    @reader.start
    w.write("\e[1;5")
    sleep 0.01 # let the reader hit its wait_readable extend loop
    w.write("H")
    w.close # EOF unblocks the reader thread so stop can join it
    @reader.stop
    r.close
    assert_equal [Thaum::KeyEvent.new(key: :home, ctrl: true)], drain
  end

  def test_real_pipe_bare_escape_resolves_to_escape
    # A genuine bare ESC keypress: nothing else follows, so the extend loop's
    # wait_readable must time out and yield a single :escape.
    r, w = IO.pipe
    @reader = Thaum::InputReader.new(input: r, queue: @queue)
    @reader.start
    w.write("\e")
    sleep Thaum::InputReader::ESCAPE_TIMEOUT * 3 # outlast the extend timeout
    w.close
    @reader.stop
    r.close
    assert_equal [Thaum::KeyEvent.new(key: :escape)], drain
  end

  def test_bracketed_paste_end_marker_split_across_chunks_emits_one_event
    # The closing \e[201~ marker is split: "...lo\e[20" then "1~". The marker
    # head ends mid-CSI, so read_chunk extends and the parser sees a complete
    # terminator instead of swallowing the partial marker into the paste body.
    @reader = Thaum::InputReader.new(input: FakeIO.new("\e[200~hel", "lo\e[20", "1~"), queue: @queue)
    @reader.start
    @reader.stop
    assert_equal [Thaum::PasteEvent.new(text: "hello")], drain
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
