# frozen_string_literal: true

require "test_helper"

class TestOctagram < Minitest::Test
  # ----- Fixtures --------------------------------------------------------

  class Leaf
    include Thaum::Sigil

    attr_reader :received_keys

    def initialize
      @received_keys = []
    end

    def on_key(event)
      @received_keys << event
      emit(event)
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.input_bg)
      canvas.text(content: "L", fg: theme.fg)
    end
  end

  # Default Octagram — passes events through to the App.
  class Passthrough
    include Thaum::Octagram

    attr_reader :received, :mounted

    def initialize(child:)
      @child    = child
      @received = []
      @mounted  = false
    end

    def partition
      vertical do
        region(height: :fill) { @child }
      end
    end

    def on_key(event)
      @received << event
      emit(event)
    end

    def on_mount
      @mounted = true
    end
  end

  # Consumes Enter; bubbles everything else.
  class EnterConsumer
    include Thaum::Octagram

    attr_reader :consumed

    def initialize(child:)
      @child = child
      @consumed = []
    end

    def partition
      vertical do
        region(height: :fill) { @child }
      end
    end

    def on_key(event)
      if event.key == :enter
        @consumed << event
      else
        emit event
      end
    end
  end

  # Renders a marker char before its child.
  class BackgroundDrawer
    include Thaum::Octagram

    def initialize(child:)
      @child = child
    end

    def partition
      vertical do
        region(height: :fill) { @child }
      end
    end

    def render(canvas:, theme:)
      canvas.text(content: "X", fg: theme.fg, x: 0, y: 0)
    end
  end

  # App with one direct Octagram child.
  class SingleOctagramApp
    include Thaum::App

    attr_reader :leaf, :oct, :app_received

    def initialize(oct_class: Passthrough)
      @leaf = Leaf.new
      @oct  = oct_class.new(child: @leaf)
      @app_received = []
    end

    def on_key(event)
      @app_received << event
    end

    def partition
      vertical do
        region(height: :fill) { @oct }
      end
    end
  end

  # App with an Octagram nested inside another Octagram.
  class NestedOctagramApp
    include Thaum::App

    attr_reader :leaf, :inner, :outer, :app_received

    def initialize
      @leaf  = Leaf.new
      @inner = Passthrough.new(child: @leaf)
      @outer = Passthrough.new(child: @inner)
      @app_received = []
    end

    def on_key(event)
      @app_received << event
    end

    def partition
      vertical do
        region(height: :fill) { @outer }
      end
    end
  end

  def rect = Thaum::Rect.new(x: 0, y: 0, width: 10, height: 3)

  def mount(app)
    app.run_partition(rect: rect)
    app.wire_sigils
    app.validate_focus_order_tree
    app
  end

  # ----- Wiring ----------------------------------------------------------

  def test_leaf_handler_parent_is_innermost_octagram
    app = mount(SingleOctagramApp.new)
    assert_same app.oct, app.leaf.handler_parent
  end

  def test_octagram_handler_parent_is_app
    app = mount(SingleOctagramApp.new)
    assert_same app, app.oct.handler_parent
  end

  def test_nested_chain_points_inward_first
    app = mount(NestedOctagramApp.new)
    assert_same app.inner, app.leaf.handler_parent
    assert_same app.outer, app.inner.handler_parent
    assert_same app, app.outer.handler_parent
  end

  def test_thaum_app_is_set_on_octagram
    app = mount(SingleOctagramApp.new)
    assert_same app, app.oct.thaum_app
  end

  # ----- Dispatch --------------------------------------------------------

  def test_child_emit_routes_through_octagram
    app   = mount(SingleOctagramApp.new)
    event = Thaum::KeyEvent.new(key: "x")
    app.leaf.emit(event)
    assert_equal [event], app.oct.received
    assert_equal [event], app.app_received
  end

  def test_octagram_can_consume_event
    app = mount(SingleOctagramApp.new(oct_class: EnterConsumer))
    enter = Thaum::KeyEvent.new(key: :enter)
    other = Thaum::KeyEvent.new(key: "x")

    app.leaf.emit(enter)
    app.leaf.emit(other)

    assert_equal [enter], app.oct.consumed
    assert_equal [other], app.app_received, "non-enter still bubbles to App"
  end

  def test_nested_octagrams_propagate_outward
    app   = mount(NestedOctagramApp.new)
    event = Thaum::KeyEvent.new(key: "z")
    app.leaf.emit(event)
    assert_equal [event], app.inner.received
    assert_equal [event], app.outer.received
    assert_equal [event], app.app_received
  end

  def test_octagram_emit_drops_framework_events
    app   = mount(SingleOctagramApp.new)
    event = Thaum::TickEvent.new(time: 0.0, delta: 0.0)
    _out, err = capture_io { app.oct.emit(event) }
    assert_empty app.app_received
    assert_match(/dropping/, err)
  end

  def test_emit_from_on_update_raises
    app = mount(SingleOctagramApp.new)
    app.oct.instance_variable_get(:@thaum_app).instance_variable_set(:@in_on_update, true)
    assert_raises(Thaum::EmitFromUpdateError) do
      app.oct.emit(Thaum::KeyEvent.new(key: "a"))
    end
  end

  # ----- Lifecycle -------------------------------------------------------

  def test_on_mount_fires_on_octagram
    app = SingleOctagramApp.new
    mount(app)
    Thaum::Tree.walk(app) do |node|
      Thaum.safe_invoke("test") { node.on_mount } if node.is_a?(Thaum::Sigil) || node.is_a?(Thaum::Octagram)
    end
    assert app.oct.mounted, "expected Octagram#on_mount to have run"
  end

  # ----- Render order ----------------------------------------------------

  def test_octagram_renders_background_before_child
    app = SingleOctagramApp.new(oct_class: BackgroundDrawer)
    mount(app)
    buffer = Thaum::Rendering::Buffer.new(width: 10, height: 3)
    Thaum::Painter.paint_node(node: app, buffer: buffer, theme: Thaum::Themes::DEFAULT)
    # BackgroundDrawer writes "X" at (0,0); the child Leaf then fills row 0 with
    # input_bg and writes "L" at (0,0). The child draws ON TOP, so cell (0,0) is "L".
    assert_equal "L", buffer.cell(x: 0, y: 0).char
  end

  # ----- partition_inset ------------------------------------------------

  class InsetOctagram
    include Thaum::Octagram

    def initialize(child:)
      @child = child
    end

    def partition
      vertical { region(height: :fill) { @child } }
    end

    def partition_inset = { top: 1, bottom: 1, left: 1, right: 1 }
  end

  def test_partition_inset_shrinks_child_rect
    leaf = Leaf.new
    app  = Class.new do
      include Thaum::App

      define_method(:initialize) do
        @oct = InsetOctagram.new(child: leaf)
        @leaf = leaf
      end
      attr_reader :oct, :leaf

      define_method(:partition) { vertical { region(height: :fill) { @oct } } }
    end.new

    app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 5))
    app.wire_sigils

    # Octagram itself keeps the outer rect; the leaf is laid out inside the inset.
    assert_equal Thaum::Rect.new(x: 0, y: 0, width: 10, height: 5), app.oct.rect
    assert_equal Thaum::Rect.new(x: 1, y: 1, width: 8, height: 3),  app.leaf.rect
  end

  def test_partition_inset_default_is_no_inset
    app = mount(SingleOctagramApp.new)
    assert_equal app.oct.rect, app.leaf.rect, "no partition_inset → child uses same rect"
  end

  # ----- on_tick / on_update auto-invocation ----------------------------

  class TickingLeaf
    include Thaum::Sigil

    attr_reader :ticks, :updates

    def initialize
      @ticks   = []
      @updates = []
    end

    def on_tick(event)     = @ticks << event
    def on_update(context) = @updates << context
    def render(canvas:, theme:); end
  end

  class TickingOctagram
    include Thaum::Octagram

    attr_reader :ticks, :updates

    def initialize(child:)
      @child   = child
      @ticks   = []
      @updates = []
    end

    def partition
      vertical { region(height: :fill) { @child } }
    end

    def on_tick(event)     = @ticks << event
    def on_update(context) = @updates << context
  end

  class TickingApp
    include Thaum::App

    attr_reader :leaf, :oct

    def initialize
      @leaf = TickingLeaf.new
      @oct  = TickingOctagram.new(child: @leaf)
    end

    def partition
      vertical { region(height: :fill) { @oct } }
    end
  end

  def test_octagram_receives_on_tick
    app = mount(TickingApp.new)
    event = Thaum::TickEvent.new(time: 1.0, delta: 0.1)
    Thaum::Dispatch.from_queue(app: app, event: event)
    assert_equal [event], app.oct.ticks
    assert_equal [event], app.leaf.ticks
  end

  def test_octagram_receives_on_update_with_context
    app = mount(TickingApp.new)
    app.update_context(foo: "bar")
    assert_equal 1, app.oct.updates.size
    assert_equal "bar", app.oct.updates.first[:foo]
    assert_equal 1, app.leaf.updates.size
    assert_equal "bar", app.leaf.updates.first[:foo]
  end

  def test_octagram_on_update_fires_before_child_sigil_on_update
    order = []
    leaf_class = Class.new do
      include Thaum::Sigil

      define_method(:initialize) { |order_ref| @order = order_ref }
      define_method(:on_update) { |_ctx| @order << :leaf }
      # render inherits the default no-op from Thaum::Sigil
    end
    oct_class = Class.new do
      include Thaum::Octagram

      define_method(:initialize) do |child, order_ref|
        @child = child
        @order = order_ref
      end
      define_method(:partition) { vertical { region(height: :fill) { @child } } }
      define_method(:on_update) { |_ctx| @order << :octagram }
    end
    app_class = Class.new do
      include Thaum::App

      define_method(:initialize) do |order_ref|
        @leaf = leaf_class.new(order_ref)
        @oct  = oct_class.new(@leaf, order_ref)
      end
      define_method(:partition) { vertical { region(height: :fill) { @oct } } }
    end
    app = mount(app_class.new(order))
    app.update_context({})
    assert_equal %i[octagram leaf], order
  end

  def test_nested_octagrams_both_receive_tick_and_update
    inner_leaf = TickingLeaf.new
    inner_oct  = TickingOctagram.new(child: inner_leaf)
    outer_oct  = TickingOctagram.new(child: inner_oct)
    app_class  = Class.new do
      include Thaum::App

      attr_reader :outer, :inner, :leaf

      define_method(:initialize) do
        @outer = outer_oct
        @inner = inner_oct
        @leaf  = inner_leaf
      end
      define_method(:partition) { vertical { region(height: :fill) { @outer } } }
    end
    app = mount(app_class.new)

    tick = Thaum::TickEvent.new(time: 2.0, delta: 0.1)
    Thaum::Dispatch.from_queue(app: app, event: tick)
    assert_equal [tick], app.outer.ticks
    assert_equal [tick], app.inner.ticks
    assert_equal [tick], app.leaf.ticks

    app.update_context(k: 1)
    assert_equal 1, app.outer.updates.size
    assert_equal 1, app.inner.updates.size
    assert_equal 1, app.leaf.updates.size
  end

  # ----- repartition: dynamic Octagram add/remove ------------------------

  class LifecycleLeaf
    include Thaum::Sigil

    attr_reader :mounted, :unmounted

    def initialize
      @mounted = 0
      @unmounted = 0
    end

    def on_mount   = (@mounted += 1)
    def on_unmount = (@unmounted += 1)
    def render(canvas:, theme:); end
  end

  class LifecycleOctagram
    include Thaum::Octagram

    attr_reader :mounted, :unmounted, :child

    def initialize(child:)
      @child = child
      @mounted = 0
      @unmounted = 0
    end

    def partition
      vertical { region(height: :fill) { @child } }
    end

    def on_mount   = (@mounted += 1)
    def on_unmount = (@unmounted += 1)
  end

  def test_repartition_fires_on_unmount_when_octagram_removed
    leaf = LifecycleLeaf.new
    oct  = LifecycleOctagram.new(child: leaf)
    other_leaf = LifecycleLeaf.new
    app_class = Class.new do
      include Thaum::App

      attr_accessor :include_oct
      attr_reader :oct, :leaf, :other

      define_method(:initialize) do
        @oct = oct
        @leaf = leaf
        @other = other_leaf
        @include_oct = true
      end

      define_method(:partition) do
        vertical do
          region(height: 1) { @other }
          region(height: :fill) { @oct } if @include_oct
        end
      end
    end

    app = mount(app_class.new)
    # First mount: simulate framework mount pass for the subtree.
    Thaum::Tree.walk(app) do |node|
      node.on_mount if node.is_a?(Thaum::Sigil) || node.is_a?(Thaum::Octagram)
    end
    assert_equal 1, app.oct.mounted
    assert_equal 1, app.leaf.mounted

    app.include_oct = false
    app.repartition

    assert_equal 1, app.oct.unmounted, "removed Octagram receives on_unmount"
    assert_equal 1, app.leaf.unmounted, "child Sigil of removed Octagram receives on_unmount"
  end

  def test_repartition_fires_on_mount_when_octagram_added
    leaf = LifecycleLeaf.new
    oct  = LifecycleOctagram.new(child: leaf)
    base_leaf = LifecycleLeaf.new
    app_class = Class.new do
      include Thaum::App

      attr_accessor :include_oct
      attr_reader :oct, :leaf, :base

      define_method(:initialize) do
        @oct = oct
        @leaf = leaf
        @base = base_leaf
        @include_oct = false
      end

      define_method(:partition) do
        vertical do
          region(height: 1) { @base }
          region(height: :fill) { @oct } if @include_oct
        end
      end
    end

    app = mount(app_class.new)
    Thaum::Tree.walk(app) do |node|
      node.on_mount if node.is_a?(Thaum::Sigil) || node.is_a?(Thaum::Octagram)
    end
    assert_equal 0, app.oct.mounted
    assert_equal 0, app.leaf.mounted

    app.include_oct = true
    app.repartition

    assert_equal 1, app.oct.mounted, "newly added Octagram receives on_mount"
    assert_equal 1, app.leaf.mounted, "newly added child Sigil receives on_mount"
    assert_same app.oct, app.leaf.handler_parent, "handler parents wired before mount"
    assert_same app, app.oct.handler_parent
  end

  def test_repartition_wires_thaum_app_on_added_octagram
    leaf = LifecycleLeaf.new
    oct  = LifecycleOctagram.new(child: leaf)
    base_leaf = LifecycleLeaf.new
    app_class = Class.new do
      include Thaum::App

      attr_accessor :include_oct
      attr_reader :oct, :leaf, :base

      define_method(:initialize) do
        @oct = oct
        @leaf = leaf
        @base = base_leaf
        @include_oct = false
      end

      define_method(:partition) do
        vertical do
          region(height: 1) { @base }
          region(height: :fill) { @oct } if @include_oct
        end
      end
    end
    app = mount(app_class.new)
    app.include_oct = true
    app.repartition
    assert_same app, app.oct.thaum_app
    assert_same app, app.leaf.thaum_app
  end
end
