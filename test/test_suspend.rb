# frozen_string_literal: true

require "test_helper"

class TestSuspend < Minitest::Test
  # Fake terminal that records setup/teardown calls and reports a configurable size.
  class FakeTerminal
    attr_reader :setup_calls, :teardown_calls
    attr_accessor :size

    def initialize(size: [80, 24])
      @size = size
      @setup_calls = 0
      @teardown_calls = 0
    end

    def setup    = (@setup_calls += 1)
    def teardown = (@teardown_calls += 1)
  end

  class NoopSigil
    include Thaum::Sigil
  end

  class SuspendApp
    include Thaum::App

    attr_reader :partition_rects

    def initialize
      @sigil = NoopSigil.new
      @partition_rects = []
    end

    def partition
      vertical { region(height: :fill) { @sigil } }
    end

    # Capture every repartition for assertions.
    def run_partition(rect:, collector: nil)
      @partition_rects << rect
      super
    end
  end

  def setup
    @app = SuspendApp.new
    @app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    @app.wire_sigils
    @app.clear_dirty
    @app.partition_rects.clear

    @terminal = FakeTerminal.new(size: [80, 24])
    @queue    = Thread::Queue.new

    # Stash signal traps so we don't leave the test process with weird handlers.
    @prev_tstp = Signal.trap("TSTP", "DEFAULT")
    @prev_cont = Signal.trap("CONT", "DEFAULT")
  end

  def teardown
    Signal.trap("TSTP", @prev_tstp) if @prev_tstp
    Signal.trap("CONT", @prev_cont) if @prev_cont
  end

  # Drive handle_suspend in a background thread so we can simulate the
  # SIGCONT-driven :resume arrival without actually stopping the process.
  # We pre-load :resume into the queue *before* handle_suspend runs; since
  # the trap is reset to DEFAULT we replace Process.kill with a no-op by
  # stubbing it just for this test.
  def run_handle_suspend
    # Stub Process.kill so the test process is not actually stopped.
    kill_calls = []
    Process.singleton_class.send(:alias_method, :__orig_kill, :kill)
    Process.singleton_class.send(:define_method, :kill) do |sig, pid|
      kill_calls << [sig, pid]
      nil
    end

    # Pre-push :resume so the post-kill queue.pop returns immediately.
    @queue.push(:resume)

    cols, rows = Thaum::Suspender.suspend(app: @app, terminal: @terminal, queue: @queue)
    [cols, rows, kill_calls]
  ensure
    Process.singleton_class.send(:remove_method, :kill)
    Process.singleton_class.send(:alias_method, :kill, :__orig_kill)
    Process.singleton_class.send(:remove_method, :__orig_kill)
  end

  def test_handle_suspend_tears_terminal_down
    run_handle_suspend
    assert_equal 1, @terminal.teardown_calls
  end

  def test_handle_suspend_kills_self_with_tstp
    _, _, kill_calls = run_handle_suspend
    assert_equal [["TSTP", Process.pid]], kill_calls
  end

  def test_handle_suspend_sets_up_terminal_after_resume
    run_handle_suspend
    assert_equal 1, @terminal.setup_calls
  end

  def test_handle_suspend_tears_down_before_setup
    seq = []
    @terminal.define_singleton_method(:teardown) { seq << :teardown }
    @terminal.define_singleton_method(:setup)    { seq << :setup }
    run_handle_suspend
    assert_equal %i[teardown setup], seq
  end

  def test_handle_suspend_repartitions_with_current_terminal_size
    @terminal.size = [120, 40]
    cols, rows, = run_handle_suspend
    assert_equal 120, cols
    assert_equal 40, rows
    refute_empty @app.partition_rects
    last = @app.partition_rects.last
    assert_equal 120, last.width
    assert_equal 40,  last.height
  end

  def test_handle_suspend_marks_app_dirty_for_full_redraw
    refute @app.dirty?
    run_handle_suspend
    assert @app.dirty?
  end

  def test_handle_suspend_drains_queue_until_resume
    # Pre-load non-resume noise; handle_suspend should ignore it and keep
    # popping until :resume.
    @queue.push(:something_else)
    @queue.push(Thaum::KeyEvent.new(key: "x"))
    @queue.push(:resume)

    kill_stub_in_place do
      Thaum::Suspender.suspend(app: @app, terminal: @terminal, queue: @queue)
    end

    assert_equal 0, @queue.size, "queue should be drained up to and including :resume"
  end

  def test_install_suspend_traps_pushes_resume_on_sigcont
    # SIGCONT is harmless to deliver to ourselves (we're not stopped), so we
    # use it to prove install_suspend_traps wires a queue-push handler.
    # TSTP can't be tested this way without actually stopping the process.
    Thaum::RunLoop.install_suspend_traps(queue: @queue)
    Process.kill("CONT", Process.pid)

    msg = @queue.pop(timeout: 1)
    assert_equal :resume, msg
  end

  private

  # Helper: stub Process.kill to a no-op for the duration of the block.
  def kill_stub_in_place
    Process.singleton_class.send(:alias_method, :__orig_kill, :kill)
    Process.singleton_class.send(:define_method, :kill) { |_sig, _pid| nil }
    yield
  ensure
    Process.singleton_class.send(:remove_method, :kill)
    Process.singleton_class.send(:alias_method, :kill, :__orig_kill)
    Process.singleton_class.send(:remove_method, :__orig_kill)
  end
end
