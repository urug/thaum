# frozen_string_literal: true

require "test_helper"

class TestMouseDispatch < Minitest::Test
  class ClickSigil
    include Thaum::Sigil

    attr_reader :events

    def initialize
      @events = []
    end

    def on_mouse(event) = (@events << event)
  end

  class NonFocusableSigil
    include Thaum::Sigil

    attr_reader :events

    def initialize
      @events = []
    end

    def focusable? = false
    def on_mouse(event) = (@events << event)
  end

  class TwoSigilApp
    include Thaum::App

    attr_reader :left, :right, :app_events

    def initialize
      @left  = ClickSigil.new
      @right = ClickSigil.new
      @app_events = []
    end

    def on_mouse(event) = (@app_events << event)

    def partition
      horizontal do
        region(width: 10) { @left }
        region(width: 10) { @right }
      end
    end
  end

  class NonFocusableApp
    include Thaum::App

    attr_reader :sigil, :app_events

    def initialize
      @sigil = NonFocusableSigil.new
      @app_events = []
    end

    def on_mouse(event) = (@app_events << event)

    def partition
      vertical { region(height: :fill) { @sigil } }
    end
  end

  class OverlapApp
    include Thaum::App

    attr_reader :first, :second, :app_events

    def initialize
      @first  = ClickSigil.new
      @second = ClickSigil.new
      @app_events = []
    end

    def on_mouse(event) = (@app_events << event)

    # Two regions stacked vertically — walk_tree visits @first before
    # @second. To exercise overlap, the test manually overrides rect so
    # both sigils share the same area; the "last in render order" should
    # be @second.
    def partition
      vertical do
        region(height: 5) { @first }
        region(height: 5) { @second }
      end
    end
  end

  def mouse(action:, abs_x:, abs_y:, button: :left)
    Thaum::MouseEvent.new(button: button, action: action, abs_x: abs_x, abs_y: abs_y)
  end

  def test_hit_test_routes_to_sigil_under_cursor
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 3, abs_y: 2))

    assert_equal 1, app.left.events.size
    assert_empty app.right.events
    assert_empty app.app_events
  end

  def test_canvas_relative_coords_are_set
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils

    # Click into the right region (which starts at x=10) at abs (12, 1)
    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 12, abs_y: 1))

    ev = app.right.events.first
    refute_nil ev
    assert_equal 12, ev.abs_x
    assert_equal 1, ev.abs_y
    assert_equal 2, ev.x # 12 - 10
    assert_equal 1, ev.y # 1 - 0
  end

  def test_no_hit_routes_to_app
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 50, abs_y: 50))

    assert_empty app.left.events
    assert_empty app.right.events
    assert_equal 1, app.app_events.size
  end

  def test_press_transfers_focus_to_focusable_sigil
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 12, abs_y: 1))

    assert_equal app.right, app.focused_sigil
  end

  def test_press_does_not_transfer_focus_to_non_focusable_sigil
    app = NonFocusableApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 1, abs_y: 1))

    assert_nil app.focused_sigil
    # Sigil still receives on_mouse regardless of focusable?.
    assert_equal 1, app.sigil.events.size
  end

  def test_release_does_not_change_focus
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils
    app.instance_variable_set(:@focused_sigil, app.left)

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :release, abs_x: 12, abs_y: 1))

    assert_equal app.left, app.focused_sigil
  end

  def test_press_auto_dirties
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils
    app.clear_dirty

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 3, abs_y: 2))

    assert app.dirty?
  end

  def test_drag_auto_dirties
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils
    app.clear_dirty

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :drag, abs_x: 3, abs_y: 2))

    assert app.dirty?
  end

  def test_scroll_auto_dirties
    app = TwoSigilApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
    app.wire_sigils
    app.clear_dirty

    Thaum::Dispatch.from_queue(
      app: app,
      event: Thaum::MouseEvent.new(button: :wheel_up, action: :scroll, abs_x: 3, abs_y: 2)
    )

    assert app.dirty?
  end

  def test_last_in_render_order_wins_on_overlap
    app = OverlapApp.new
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 10))
    app.wire_sigils
    # Force both sigils to share the same rect — test that LATER one wins.
    shared = Thaum::Rect.new(x: 0, y: 0, width: 20, height: 10)
    app.first.instance_variable_set(:@rect, shared)
    app.second.instance_variable_set(:@rect, shared)

    Thaum::Dispatch.from_queue(app: app, event: mouse(action: :press, abs_x: 5, abs_y: 5))

    assert_empty app.first.events
    assert_equal 1, app.second.events.size
  end
end
