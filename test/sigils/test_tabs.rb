# frozen_string_literal: true

require "test_helper"

class TestTabsWidget < Minitest::Test
  def buffer(w: 30, h: 1) = Thaum::Rendering::Buffer.new(width: w, height: h)

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def theme = Thaum::Themes::DEFAULT
  def key(k) = Thaum::KeyEvent.new(key: k)

  # ----- State ---------------------------------------------------------

  def test_default_active_is_zero
    t = Thaum::Tabs.new(labels: %w[One Two Three])
    assert_equal 0, t.active
    assert_equal "One", t.current
  end

  def test_initial_active_clamps_to_range
    t = Thaum::Tabs.new(labels: %w[A B], active: 99)
    assert_equal 1, t.active
  end

  def test_empty_labels_raises
    assert_raises(ArgumentError) { Thaum::Tabs.new(labels: []) }
  end

  # ----- Navigation ---------------------------------------------------

  def test_right_advances
    t = Thaum::Tabs.new(labels: %w[A B C])
    t.on_key(key(:right))
    assert_equal 1, t.active
  end

  def test_left_walks_backward
    t = Thaum::Tabs.new(labels: %w[A B C], active: 1)
    t.on_key(key(:left))
    assert_equal 0, t.active
  end

  def test_right_wraps_from_last_to_first
    t = Thaum::Tabs.new(labels: %w[A B C], active: 2)
    t.on_key(key(:right))
    assert_equal 0, t.active
  end

  def test_left_wraps_from_first_to_last
    t = Thaum::Tabs.new(labels: %w[A B C], active: 0)
    t.on_key(key(:left))
    assert_equal 2, t.active
  end

  def test_navigation_emits_activated
    t = Thaum::Tabs.new(labels: %w[A B C])
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    t.on_key(key(:right))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::Tabs::ActivatedEvent, emitted.first
    assert_equal 1, emitted.first.index
    assert_equal "B", emitted.first.label
  end

  def test_single_tab_navigation_is_silent
    # Wrap-around on a single-element list lands back on the same index;
    # don't emit since nothing changed.
    t = Thaum::Tabs.new(labels: ["Only"])
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    t.on_key(key(:right))
    assert_empty emitted
  end

  def test_unhandled_key_propagates
    t = Thaum::Tabs.new(labels: %w[A B])
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    evt = key(:f1)
    t.on_key(evt)
    assert_equal [evt], emitted
  end

  # ----- Render --------------------------------------------------------

  def test_render_shows_all_labels
    t = Thaum::Tabs.new(labels: %w[One Two Three])
    buf = buffer
    t.render(canvas: canvas(buf), theme: theme)
    row = buf.row_text(y: 0)
    assert_includes row, "One"
    assert_includes row, "Two"
    assert_includes row, "Three"
  end

  def test_render_highlights_active_tab
    t = Thaum::Tabs.new(labels: %w[A B C], active: 1)
    buf = buffer
    t.render(canvas: canvas(buf), theme: theme)
    # Find "B" in the row; its cell should have selection bg.
    row = buf.row_text(y: 0)
    b_idx = row.index("B")
    assert b_idx
    assert_equal theme.selection, buf.cell(x: b_idx, y: 0).style.bg
  end
end
