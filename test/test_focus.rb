# frozen_string_literal: true

require "test_helper"

class TestFocus < Minitest::Test
  # ---- Test fixtures ----------------------------------------------------

  class Box
    include Thaum::Sigil

    def initialize(label = nil) = @label = label
    attr_reader :label
  end

  class NonFocusable
    include Thaum::Sigil

    def focusable? = false
  end

  def rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)

  # A nested Layout class — lets us cover Layout subclass behavior
  class Pane
    include Thaum::Concerns::Layout

    def initialize(sigils)
      @sigils = sigils
    end

    def partition
      vertical do
        @sigils.each { |s| region(height: :fill) { s } }
      end
    end
  end

  # Apps used across tests ------------------------------------------------

  class FlatApp
    include Thaum::App

    attr_reader :a, :b, :c

    def initialize
      @a = Box.new(:a)
      @b = Box.new(:b)
      @c = Box.new(:c)
    end

    def partition
      vertical do
        region(height: 1) { @a }
        region(height: 1) { @b }
        region(height: 1) { @c }
      end
    end
  end

  class ReorderedApp < FlatApp
    def focus_order = [@c, @a, @b]
  end

  class MissingOrderApp < FlatApp
    # focus_order is missing @c.
    def focus_order = [@a, @b]
  end

  class DupedOrderApp < FlatApp
    # focus_order lists @a twice.
    def focus_order = [@a, @b, @c, @a]
  end

  class StrangerOrderApp < FlatApp
    # focus_order names a sigil that isn't in the tree.
    def focus_order = [@a, @b, @c, Box.new(:stranger)]
  end

  class NestedApp
    include Thaum::App

    attr_reader :sidebar_a, :sidebar_b, :main

    def initialize
      @sidebar_a = Box.new(:sa)
      @sidebar_b = Box.new(:sb)
      @main      = Box.new(:m)
      @sidebar   = Pane.new([@sidebar_a, @sidebar_b])
    end

    def partition
      horizontal do
        region(width: 20)    { @sidebar }
        region(width: :fill) { @main }
      end
    end
  end

  class NestedReorderedApp < NestedApp
    # Re-order at the App level: main first, then both sidebar leaves.
    def focus_order = [@main, @sidebar_a, @sidebar_b]
  end

  # Helper to fully mount an App (partition + wire + validate)
  def mount(app)
    app.run_partition(rect: rect)
    app.wire_sigils
    app.validate_focus_order_tree
    app
  end

  # ---- focus_order validation ------------------------------------------

  def test_no_focus_order_does_not_raise
    mount(FlatApp.new)
  end

  def test_complete_focus_order_does_not_raise
    mount(ReorderedApp.new)
  end

  def test_missing_focusable_raises
    err = assert_raises(Thaum::FocusOrderError) { mount(MissingOrderApp.new) }
    assert_match(/missing/, err.message)
  end

  def test_duplicate_entry_raises
    err = assert_raises(Thaum::FocusOrderError) { mount(DupedOrderApp.new) }
    assert_match(/duplicates/, err.message)
  end

  def test_unknown_entry_raises
    err = assert_raises(Thaum::FocusOrderError) { mount(StrangerOrderApp.new) }
    assert_match(/unknown/, err.message)
  end

  def test_non_array_focus_order_raises
    klass = Class.new(FlatApp) { def focus_order = :nope }
    err = assert_raises(Thaum::FocusOrderError) { mount(klass.new) }
    assert_match(/must return an Array/, err.message)
  end

  def test_non_focusable_sigils_excluded_from_focus_order_check
    # focus_order lists only focusable leaves; a NonFocusable in the tree must not require listing.
    klass = Class.new do
      include Thaum::App

      attr_reader :a, :hidden

      def initialize
        @a = Box.new
        @hidden = NonFocusable.new
      end

      def partition
        vertical do
          region(height: 1) { @a }
          region(height: 1) { @hidden }
        end
      end

      def focus_order = [@a]
    end
    mount(klass.new) # must not raise
  end

  # ---- focus_next / focus_prev cycling ---------------------------------

  def test_focus_next_follows_default_leaf_order
    app = mount(FlatApp.new)
    app.focus(app.a)
    app.focus_next
    assert_same app.b, app.focused_sigil
    app.focus_next
    assert_same app.c, app.focused_sigil
    app.focus_next
    assert_same app.a, app.focused_sigil # wraps
  end

  def test_focus_prev_walks_backward
    app = mount(FlatApp.new)
    app.focus(app.a)
    app.focus_prev
    assert_same app.c, app.focused_sigil
    app.focus_prev
    assert_same app.b, app.focused_sigil
  end

  def test_focus_next_with_no_current_focus_lands_on_first
    app = mount(FlatApp.new)
    refute app.focused_sigil
    app.focus_next
    assert_same app.a, app.focused_sigil
  end

  def test_focus_order_overrides_traversal_at_app_level
    app = mount(ReorderedApp.new)
    app.focus(app.c)
    app.focus_next
    assert_same app.a, app.focused_sigil
    app.focus_next
    assert_same app.b, app.focused_sigil
    app.focus_next
    assert_same app.c, app.focused_sigil # wraps
  end

  def test_nested_layout_traversal_uses_default_leaf_order
    app = mount(NestedApp.new)
    app.focus(app.sidebar_a)
    app.focus_next
    assert_same app.sidebar_b, app.focused_sigil
    app.focus_next
    assert_same app.main, app.focused_sigil
  end

  def test_nested_app_focus_order_reorders_subtree
    app = mount(NestedReorderedApp.new)
    app.focus(app.main)
    app.focus_next
    assert_same app.sidebar_a, app.focused_sigil
    app.focus_next
    assert_same app.sidebar_b, app.focused_sigil
    app.focus_next
    assert_same app.main, app.focused_sigil
  end

  # ---- Tab dispatch interception ---------------------------------------

  def test_emit_of_tab_advances_focus_then_calls_app_on_key
    received = []
    klass = Class.new(FlatApp) do
      define_method(:on_key) { |e| received << e }
    end
    app = mount(klass.new)
    app.focus(app.a)
    app.a.emit(Thaum::KeyEvent.new(key: :tab))
    assert_same app.b, app.focused_sigil
    assert_equal 1, received.size
    assert_equal :tab, received.first.key
  end

  def test_emit_of_shift_tab_walks_backward
    klass = Class.new(FlatApp)
    app = mount(klass.new)
    app.focus(app.a)
    app.a.emit(Thaum::KeyEvent.new(key: :tab, shift: true))
    assert_same app.c, app.focused_sigil
  end

  def test_tab_when_no_sigil_focused_lands_on_first
    klass = Class.new(FlatApp)
    app = mount(klass.new)
    refute app.focused_sigil
    Thaum::Dispatch.from_queue(app: app, event: Thaum::KeyEvent.new(key: :tab))
    assert_same app.a, app.focused_sigil
  end

  # ---- repartition re-validates ----------------------------------------

  # ---- Scoped Tab cycling within Octagrams -----------------------------

  class OctagramWithChildren
    include Thaum::Octagram

    attr_reader :children

    def initialize(children)
      @children = children
    end

    def partition
      vertical do
        @children.each { |c| region(height: :fill) { c } }
      end
    end
  end

  # App with one Octagram containing two leaves, plus one leaf outside.
  class AppWithOctagram
    include Thaum::App

    attr_reader :outer_leaf, :inner_a, :inner_b, :oct

    def initialize
      @outer_leaf = Box.new(:outer)
      @inner_a    = Box.new(:ia)
      @inner_b    = Box.new(:ib)
      @oct        = OctagramWithChildren.new([@inner_a, @inner_b])
    end

    def partition
      vertical do
        region(height: 1)    { @outer_leaf }
        region(height: :fill) { @oct }
      end
    end
  end

  def test_tab_cycles_within_octagram_first
    app = mount(AppWithOctagram.new)
    app.focus(app.inner_a)
    app.inner_a.emit(Thaum::KeyEvent.new(key: :tab))
    assert_same app.inner_b, app.focused_sigil, "Tab cycles within Octagram"
  end

  def test_tab_at_end_of_octagram_propagates_outward
    app = mount(AppWithOctagram.new)
    app.focus(app.inner_b)
    app.inner_b.emit(Thaum::KeyEvent.new(key: :tab))
    # Octagram is at the end of App's units → wraps to outer_leaf.
    assert_same app.outer_leaf, app.focused_sigil
  end

  def test_shift_tab_cycles_backward_within_octagram
    app = mount(AppWithOctagram.new)
    app.focus(app.inner_b)
    app.inner_b.emit(Thaum::KeyEvent.new(key: :tab, shift: true))
    assert_same app.inner_a, app.focused_sigil
  end

  def test_shift_tab_at_start_of_octagram_propagates_outward
    app = mount(AppWithOctagram.new)
    app.focus(app.inner_a)
    app.inner_a.emit(Thaum::KeyEvent.new(key: :tab, shift: true))
    assert_same app.outer_leaf, app.focused_sigil
  end

  def test_octagram_appears_as_single_unit_in_app_scope
    # outer_leaf → Tab → enters Octagram at its first focusable leaf (inner_a)
    app = mount(AppWithOctagram.new)
    app.focus(app.outer_leaf)
    app.outer_leaf.emit(Thaum::KeyEvent.new(key: :tab))
    assert_same app.inner_a, app.focused_sigil
  end

  def test_shift_tab_into_octagram_enters_at_last_leaf
    app = mount(AppWithOctagram.new)
    app.focus(app.outer_leaf)
    app.outer_leaf.emit(Thaum::KeyEvent.new(key: :tab, shift: true))
    # outer_leaf is first; Shift-Tab wraps to the Octagram unit, entering at last.
    assert_same app.inner_b, app.focused_sigil
  end

  # Multi-Octagram app — Tab at end of inner Octagram bubbles to next outer.
  class TwoOctagramApp
    include Thaum::App

    attr_reader :a, :b, :c, :d, :oct1, :oct2

    def initialize
      @a = Box.new(:a)
      @b = Box.new(:b)
      @c = Box.new(:c)
      @d = Box.new(:d)
      @oct1 = OctagramWithChildren.new([@a, @b])
      @oct2 = OctagramWithChildren.new([@c, @d])
    end

    def partition
      vertical do
        region(height: :fill) { @oct1 }
        region(height: :fill) { @oct2 }
      end
    end
  end

  def test_tab_from_last_leaf_of_inner_octagram_enters_next_outer_octagram
    app = mount(TwoOctagramApp.new)
    app.focus(app.b) # last leaf of oct1
    app.b.emit(Thaum::KeyEvent.new(key: :tab))
    assert_same app.c, app.focused_sigil, "Tab bubbles out of oct1, enters oct2 at first leaf"
  end

  def test_tab_wraps_at_app_scope_across_octagrams
    app = mount(TwoOctagramApp.new)
    app.focus(app.d) # last leaf of last Octagram
    app.d.emit(Thaum::KeyEvent.new(key: :tab))
    assert_same app.a, app.focused_sigil, "wraps to first leaf of first Octagram"
  end

  def test_shift_tab_from_first_leaf_of_outer_octagram_enters_previous
    app = mount(TwoOctagramApp.new)
    app.focus(app.c)
    app.c.emit(Thaum::KeyEvent.new(key: :tab, shift: true))
    assert_same app.b, app.focused_sigil, "Shift-Tab from first leaf of oct2 enters oct1 at last"
  end

  # Nested Octagrams: outer contains inner contains leaves.
  class NestedOctagramApp
    include Thaum::App

    attr_reader :outer, :inner, :a, :b, :sibling

    def initialize
      @a = Box.new(:a)
      @b = Box.new(:b)
      @sibling = Box.new(:sib)
      @inner = OctagramWithChildren.new([@a, @b])
      @outer = OctagramWithChildren.new([@inner, @sibling])
    end

    def partition
      vertical do
        region(height: :fill) { @outer }
      end
    end
  end

  def test_tab_from_end_of_inner_octagram_propagates_to_outer_octagram
    app = mount(NestedOctagramApp.new)
    app.focus(app.b)
    app.b.emit(Thaum::KeyEvent.new(key: :tab))
    # inner has [a, b]; from b Tab bubbles to outer with [inner, sibling];
    # current unit is inner → next is sibling.
    assert_same app.sibling, app.focused_sigil
  end

  def test_tab_from_end_of_outer_octagram_wraps_back_to_inner_first_leaf
    app = mount(NestedOctagramApp.new)
    app.focus(app.sibling)
    app.sibling.emit(Thaum::KeyEvent.new(key: :tab))
    # outer scope wraps; App scope has just [outer]; wraps inside outer to inner's first leaf.
    assert_same app.a, app.focused_sigil
  end

  def test_repartition_revalidates_focus_order
    # Reuse ReorderedApp; remove @b from partition via singleton override.
    app = mount(ReorderedApp.new)
    app.define_singleton_method(:partition) do
      vertical do
        region(height: 1) { @a }
        region(height: 1) { @c }
      end
    end
    # focus_order still references @b, which is no longer in the tree → unknown entry.
    err = assert_raises(Thaum::FocusOrderError) { app.repartition }
    assert_match(/unknown/, err.message)
  end
end
