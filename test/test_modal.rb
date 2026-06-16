# frozen_string_literal: true

require "test_helper"

class TestModal < Minitest::Test
  # ---- Fixtures ---------------------------------------------------------

  class Recorder
    include Thaum::Sigil

    attr_reader :events
    attr_accessor :char

    def initialize(char: "M")
      @events = []
      @char   = char
    end

    def on_mount     = (@events << :mount)
    def on_unmount   = (@events << :unmount)
    def on_focus     = (@events << :focus)
    def on_blur      = (@events << :blur)
    def on_key(e)    = (@events << [:key, e])
    def on_paste(e)  = (@events << [:paste, e])
    def on_tick(e)   = (@events << [:tick, e])
    def on_update(c) = (@events << [:update, c])

    def render(canvas:, theme:)
      canvas.fill(char: @char)
    end
  end

  class Leaf
    include Thaum::Sigil

    attr_reader :events

    def initialize = (@events = [])

    def on_focus   = (@events << :focus)
    def on_blur    = (@events << :blur)
    def on_key(e)  = (@events << [:key, e])
    def on_tick(e) = (@events << [:tick, e])
    def on_update(c) = (@events << [:update, c])

    def render(canvas:, theme:)
      canvas.fill(char: "L")
    end
  end

  class TestApp
    include Thaum::App

    attr_reader :leaf, :order, :received_events

    def initialize
      @leaf  = Leaf.new
      @order = []
      @received_events = []
    end

    def partition
      vertical { region(height: :fill) { @leaf } }
    end

    def on_tick(_e)  = (@order << :app)
    def on_event(e)  = (@received_events << e)
  end

  RECT = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24).freeze

  def mount_app
    app = TestApp.new
    app.run_partition(rect: RECT)
    app.wire_sigils
    app.validate_focus_order_tree
    app
  end

  # ---- show_modal / hide_modal core ------------------------------------

  def test_show_modal_mounts_and_focuses
    app    = mount_app
    modal  = Recorder.new
    app.show_modal(sigil: modal, width: 20, height: 10)

    assert_same modal, app.modal_sigil
    assert_equal %i[mount focus], modal.events
    assert app.modal_active?
  end

  def test_show_modal_centers_by_default
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 20, height: 10)
    rect = app.modal_rect

    assert_equal 20, rect.width
    assert_equal 10, rect.height
    assert_equal (80 - 20) / 2, rect.x
    assert_equal (24 - 10) / 2, rect.y
  end

  def test_show_modal_explicit_xy
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 20, height: 10, x: 5, y: 2)
    rect = app.modal_rect

    assert_equal 5,  rect.x
    assert_equal 2,  rect.y
    assert_equal 20, rect.width
    assert_equal 10, rect.height
  end

  def test_show_modal_wires_thaum_app_for_emit
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)

    assert_same app, modal.thaum_app
    # Emit from the modal reaches App#on_event.
    evt = Thaum::Event.define(:tag).new(tag: :hello)
    modal.emit(evt)
    assert_equal [evt], app.received_events
  end

  def test_hide_modal_unmounts_and_restores_focus
    app   = mount_app
    modal = Recorder.new
    app.focus(app.leaf)
    app.leaf.events.clear

    app.show_modal(sigil: modal, width: 10, height: 5)
    # Showing the modal blurred the leaf and focused the modal.
    assert_equal [:blur], app.leaf.events
    assert_equal %i[mount focus], modal.events

    app.hide_modal

    assert_nil app.modal_sigil
    refute app.modal_active?
    assert_equal %i[mount focus blur unmount], modal.events
    assert_same app.leaf, app.focused_sigil
    assert_equal %i[blur focus], app.leaf.events
  end

  def test_hide_modal_with_no_modal_is_noop
    app = mount_app
    app.hide_modal # must not raise
    assert_nil app.modal_sigil
  end

  def test_show_modal_replaces_existing_modal
    app = mount_app
    app.focus(app.leaf)
    first  = Recorder.new(char: "A")
    second = Recorder.new(char: "B")
    app.show_modal(sigil: first, width: 10, height: 5)
    app.show_modal(sigil: second, width: 12, height: 6)

    assert_equal %i[mount focus blur unmount], first.events
    assert_equal %i[mount focus], second.events
    assert_same second, app.modal_sigil

    # hide_modal still restores the original underlying focus.
    app.hide_modal
    assert_same app.leaf, app.focused_sigil
  end

  # ---- Escape interception ---------------------------------------------

  def test_escape_calls_hide_modal_and_modal_on_key_does_not_see_it
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: :escape)
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_nil app.modal_sigil
    # Modal received on_blur + on_unmount but NOT the escape on_key.
    assert_equal %i[blur unmount], modal.events
  end

  def test_escape_with_modifier_is_not_intercepted
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: :escape, shift: true)
    Thaum::Dispatch.from_queue(app: app, event: evt)

    # Modifier means modal still sees it; modal stays active.
    assert_same modal, app.modal_sigil
    assert_equal [[:key, evt]], modal.events
  end

  # ---- Tab is eaten while modal active ---------------------------------

  def test_tab_eaten_when_modal_active_no_focus
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: :tab)
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_empty(modal.events.select { |e| e.is_a?(Array) && e[0] == :key })
  end

  def test_shift_tab_eaten_when_modal_active
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: :tab, shift: true)
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_empty(modal.events.select { |e| e.is_a?(Array) && e[0] == :key })
  end

  def test_focus_next_is_noop_while_modal_active
    app = mount_app
    app.focus(app.leaf)
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    # show_modal cleared underlying focus.
    assert_nil app.focused_sigil

    app.focus_next
    app.focus_prev
    app.focus(app.leaf)

    assert_nil app.focused_sigil
    assert_same modal, app.modal_sigil
  end

  def test_bubbled_tab_from_modal_is_eaten
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)

    # Modal-emitted Tab should not cycle focus and should not reach App#on_key.
    received_app_key = []
    app.define_singleton_method(:on_key) { |e| received_app_key << e }

    modal.emit(Thaum::KeyEvent.new(key: :tab))
    assert_empty received_app_key
    assert_nil app.focused_sigil
  end

  # ---- Keyboard / paste routing ----------------------------------------

  def test_key_event_routes_to_modal_only
    app = mount_app
    app.focus(app.leaf)
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)

    # Clear pre-modal blur on leaf and mount/focus on modal.
    app.leaf.events.clear
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: "x")
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_equal [[:key, evt]], modal.events
    assert_empty app.leaf.events
  end

  def test_paste_event_routes_to_modal_only
    app = mount_app
    app.focus(app.leaf)
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    app.leaf.events.clear
    modal.events.clear

    evt = Thaum::PasteEvent.new(text: "hi")
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_equal [[:paste, evt]], modal.events
    assert_empty app.leaf.events
  end

  def test_key_event_routes_to_modal_even_without_underlying_focus
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    modal.events.clear

    evt = Thaum::KeyEvent.new(key: "x")
    Thaum::Dispatch.from_queue(app: app, event: evt)

    assert_equal [[:key, evt]], modal.events
  end

  # ---- Tick / update ----------------------------------------------------

  def test_tick_fires_modal_sigil_last
    app   = mount_app
    modal = Recorder.new
    order = []
    app.define_singleton_method(:on_tick) { |_e| order << :app }
    app.leaf.define_singleton_method(:on_tick) { |_e| order << :leaf }
    modal.define_singleton_method(:on_tick) { |_e| order << :modal }
    app.show_modal(sigil: modal, width: 10, height: 5)

    Thaum::Dispatch.from_queue(app: app, event: Thaum::TickEvent.new(time: 1.0, delta: 0.1))

    assert_equal %i[app leaf modal], order
  end

  def test_update_context_walks_modal_last
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    app.leaf.events.clear
    modal.events.clear

    app.update_context({ k: 1 })

    assert_equal [[:update, { k: 1 }]], app.leaf.events
    assert_equal [[:update, { k: 1 }]], modal.events
  end

  # ---- Resize -----------------------------------------------------------

  def test_resize_recenters_default_centered_modal
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 20, height: 10)
    pre = app.modal_rect
    assert_equal (80 - 20) / 2, pre.x

    # Simulate the run-loop resize handling.
    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 100, height: 30))
    app.recompute_modal_rect

    post = app.modal_rect
    assert_equal (100 - 20) / 2, post.x
    assert_equal (30 - 10) / 2, post.y
    assert_same post, modal.rect
  end

  def test_resize_does_not_recenter_explicit_xy_modal
    app   = mount_app
    modal = Recorder.new
    app.show_modal(sigil: modal, width: 20, height: 10, x: 3, y: 4)

    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 100, height: 30))
    app.recompute_modal_rect

    post = app.modal_rect
    assert_equal 3, post.x
    assert_equal 4, post.y
  end

  # ---- Render -----------------------------------------------------------

  def test_modal_renders_over_layout
    app   = mount_app
    # Make the leaf paint "L" everywhere.
    modal = Recorder.new(char: "M")
    app.show_modal(sigil: modal, width: 4, height: 2, x: 10, y: 5)

    buffer = Thaum::Rendering::Buffer.new(width: 80, height: 24)
    Thaum::Painter.paint_node(node: app, buffer: buffer, theme: app.theme)
    Thaum::Painter.paint_modal(app: app, buffer: buffer, theme: app.theme)

    # Modal cells: rows 5-6, cols 10-13 → "M"
    (5..6).each do |y|
      (10..13).each do |x|
        assert_equal "M", buffer.cell(x: x, y: y).char,
                     "expected modal char at (#{x},#{y})"
      end
    end
    # Outside modal still "L".
    assert_equal "L", buffer.cell(x: 0, y: 0).char
    assert_equal "L", buffer.cell(x: 9, y: 5).char
    assert_equal "L", buffer.cell(x: 14, y: 5).char
  end

  def test_modal_clips_when_partially_offscreen
    app   = mount_app
    modal = Recorder.new(char: "M")
    # Modal extends past right and bottom edges.
    app.show_modal(sigil: modal, width: 10, height: 10, x: 75, y: 20)

    buffer = Thaum::Rendering::Buffer.new(width: 80, height: 24)
    Thaum::Painter.paint_node(node: app, buffer: buffer, theme: app.theme)
    Thaum::Painter.paint_modal(app: app, buffer: buffer, theme: app.theme)

    # On-screen modal cells visible.
    assert_equal "M", buffer.cell(x: 75, y: 20).char
    assert_equal "M", buffer.cell(x: 79, y: 23).char
    # Out-of-bounds cells silently dropped — nothing to assert beyond no raise.
  end

  # ---- Misc -------------------------------------------------------------

  def test_show_modal_with_no_prior_focus_does_not_set_previous_focus
    app = mount_app
    refute app.focused_sigil

    modal = Recorder.new
    app.show_modal(sigil: modal, width: 10, height: 5)
    app.hide_modal

    # No prior focus to restore; focused_sigil stays nil.
    assert_nil app.focused_sigil
  end

  def test_replacing_modal_preserves_original_previous_focus
    app = mount_app
    app.focus(app.leaf)

    first  = Recorder.new
    second = Recorder.new
    app.show_modal(sigil: first, width: 10, height: 5)
    app.show_modal(sigil: second, width: 12, height: 6)
    app.hide_modal

    # The original underlying focus is restored, not the (nil) intermediate.
    assert_same app.leaf, app.focused_sigil
  end
end
