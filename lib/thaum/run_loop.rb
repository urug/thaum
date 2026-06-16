# frozen_string_literal: true

module Thaum
  # Owns the main run loop: terminal setup, the event queue, mount/draw
  # pass, suspend/resume choreography, and graceful teardown.
  module RunLoop
    module_function

    # Startup entry point. Blocks until app.quit is called. Returns nil.
    def run(app:, tick: 0.1, threads: 4)
      terminal   = Terminal.new
      queue      = Thread::Queue.new
      capability = Color.detect(ENV)
      warn "[Thaum] color not supported, rendering without color" if capability == :none
      renderer   = Rendering::Renderer.new(capability: capability)
      pool       = Concurrent::FixedThreadPool.new(threads)
      tick_task  = build_tick_task(queue:, interval: tick)

      Thaum::Action.queue = queue
      Thaum::Action.pool  = pool

      install_traps(queue:, terminal:)
      terminal.setup
      cols, rows = terminal.size

      mount_pass(app:, renderer:, cols:, rows:)

      input_reader = InputReader.new(input: $stdin, queue: queue)
      input_reader.start
      tick_task.execute

      event_loop(app:, queue:, terminal:, renderer:, cols:, rows:)
    ensure
      tick_task&.shutdown
      input_reader&.stop
      shutdown_pool(pool:)
      Thaum::Action.queue = nil
      Thaum::Action.pool  = nil
      terminal&.teardown
    end

    def event_loop(app:, queue:, terminal:, renderer:, cols:, rows:)
      until app.quit?
        event = queue.pop

        if event == :suspend
          cols, rows = Suspender.suspend(app:, terminal:, queue:)
          next
        end
        # Stray :resume outside a suspend window — ignore.
        next if event == :resume

        cols, rows = handle_resize(app:, event:, _cols: cols, _rows: rows) if event.is_a?(ResizeEvent)

        Dispatch.from_queue(app:, event:)

        next unless app.dirty?

        app.clear_dirty
        Thaum.safe_invoke("render") { Painter.paint(app:, renderer:, cols:, rows:) }
      end
      [cols, rows]
    end

    def mount_pass(app:, renderer:, cols:, rows:)
      app.run_partition(rect: Rect.new(x: 0, y: 0, width: cols, height: rows))
      app.wire_sigils
      app.validate_focus_order_tree
      Thaum.safe_invoke("App#on_mount") { app.on_mount }
      Tree.walk(app) do |node|
        next unless node.is_a?(Sigil) || node.is_a?(Octagram)

        Thaum.safe_invoke("#{node.class}#on_mount") { node.on_mount }
      end

      first = Thaum.safe_invoke("App#initial_focus") { app.initial_focus }
      if first
        app.set_initial_focus(first)
        Thaum.safe_invoke("#{first.class}#on_focus") { first.on_focus }
      end

      Painter.paint(app:, renderer:, cols:, rows:)
    end

    def handle_resize(app:, event:, _cols: nil, _rows: nil)
      cols = event.width
      rows = event.height
      Thaum.safe_invoke("App#run_partition") do
        app.run_partition(rect: Rect.new(x: 0, y: 0, width: cols, height: rows))
      end
      Thaum.safe_invoke("App#recompute_modal_rect") { app.recompute_modal_rect }
      [cols, rows]
    end

    def build_tick_task(queue:, interval:)
      last_tick = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Concurrent::TimerTask.new(execution_interval: interval) do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        queue.push(TickEvent.new(time: now, delta: now - last_tick))
        last_tick = now
      end
    end

    def install_traps(queue:, terminal:)
      install_resize_trap(queue:, terminal:)
      install_suspend_traps(queue:)
    end

    # Push a ResizeEvent on SIGWINCH.
    def install_resize_trap(queue:, terminal:)
      Signal.trap("WINCH") do
        w, h = terminal.size
        begin
          queue.push(ResizeEvent.new(width: w, height: h))
        rescue ClosedQueueError
          nil
        end
      end
    end

    # Push :suspend / :resume sentinels onto the main queue from signal
    # handlers. The actual suspend dance happens in Suspender so the signal
    # handler stays minimal (signal-handler context has tight restrictions).
    def install_suspend_traps(queue:)
      Signal.trap("TSTP") do
        queue.push(:suspend)
      rescue ClosedQueueError
        nil
      end
      Signal.trap("CONT") do
        queue.push(:resume)
      rescue ClosedQueueError
        nil
      end
    end

    def shutdown_pool(pool:)
      return unless pool

      pool.shutdown
      pool.wait_for_termination(1) || pool.kill
    end
  end

  # Handles a dequeued :suspend sentinel: tear the terminal down, actually
  # stop the process, then on resume re-setup, repartition with current
  # size, and force a re-render. Drains stray sentinels that arrive
  # between teardown and resume. Internal — not delivered to App handlers
  # per the spec.
  module Suspender
    module_function

    def suspend(app:, terminal:, queue:)
      Thaum.safe_invoke("Terminal#teardown(suspend)") { terminal.teardown }

      # Reset TSTP to default so kill("TSTP", pid) actually stops us.
      prev_tstp = Signal.trap("TSTP", "DEFAULT")
      Process.kill("TSTP", Process.pid)
      # ── process is stopped here; resumes when shell sends SIGCONT ──
      Signal.trap("TSTP", prev_tstp)

      drain_until_resume(queue:)

      Thaum.safe_invoke("Terminal#setup(resume)") { terminal.setup }
      cols, rows = terminal.size
      Thaum.safe_invoke("App#run_partition(resume)") do
        app.run_partition(rect: Rect.new(x: 0, y: 0, width: cols, height: rows))
      end
      app.request_render
      [cols, rows]
    end

    def drain_until_resume(queue:)
      loop do
        msg = queue.pop
        break if msg == :resume
        # Ignore everything else during the suspended window — we
        # re-render from scratch on resume anyway.
      end
    end
  end
end
