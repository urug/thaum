# frozen_string_literal: true

require "test_helper"

class TestSelectWidget < Minitest::Test
  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: 20, height: 5)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  # --- State ---

  def test_default_cursor_is_zero
    s = Thaum::Select.new(items: %w[a b c])
    assert_equal 0, s.cursor
    assert_equal %w[a b c], s.items
  end

  def test_initial_cursor_can_be_set
    s = Thaum::Select.new(items: %w[a b c], cursor: 2)
    assert_equal 2, s.cursor
  end

  def test_empty_items_is_allowed
    s = Thaum::Select.new(items: [])
    assert_equal 0, s.cursor
    assert_nil s.current
  end

  # --- Navigation ---

  def test_down_advances_cursor
    s = Thaum::Select.new(items: %w[a b c])
    s.on_key(Thaum::KeyEvent.new(key: :down))
    assert_equal 1, s.cursor
  end

  def test_down_clamps_at_end
    s = Thaum::Select.new(items: %w[a b c], cursor: 2)
    s.on_key(Thaum::KeyEvent.new(key: :down))
    assert_equal 2, s.cursor
  end

  def test_up_retreats_cursor
    s = Thaum::Select.new(items: %w[a b c], cursor: 2)
    s.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 1, s.cursor
  end

  def test_up_clamps_at_zero
    s = Thaum::Select.new(items: %w[a b c])
    s.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 0, s.cursor
  end

  # --- Selection ---

  def test_enter_emits_selected_with_index_and_item
    s = Thaum::Select.new(items: %w[apple banana cherry], cursor: 1)
    emitted = []
    s.define_singleton_method(:emit) { |e| emitted << e }
    s.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::Select::SelectedEvent, emitted.first
    assert_equal 1, emitted.first.index
    assert_equal "banana", emitted.first.item
  end

  def test_enter_with_empty_items_does_not_emit_selected
    s = Thaum::Select.new(items: [])
    emitted = []
    s.define_singleton_method(:emit) { |e| emitted << e }
    s.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_empty emitted
  end

  def test_unhandled_key_propagates
    s = Thaum::Select.new(items: %w[a])
    emitted = []
    s.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::KeyEvent.new(key: :f1)
    s.on_key(evt)
    assert_equal [evt], emitted
  end

  # --- Rendering ---

  def test_renders_items_each_on_own_row
    s = Thaum::Select.new(items: %w[one two three])
    s.render(canvas: canvas, theme: theme)
    assert_equal "one",   buffer.row_text(y: 0).strip
    assert_equal "two",   buffer.row_text(y: 1).strip
    assert_equal "three", buffer.row_text(y: 2).strip
  end

  def test_cursor_row_gets_selection_background
    s = Thaum::Select.new(items: %w[a b c], cursor: 1)
    s.render(canvas: canvas, theme: theme)
    assert_equal theme.selection, buffer.cell(x: 0, y: 1).style.bg
    refute_equal theme.selection, buffer.cell(x: 0, y: 0).style.bg
  end

  # --- Scrolling ---

  def test_scrolls_when_cursor_below_visible_window
    # 10 items, canvas is 5 rows tall, cursor at 7 → visible should be 3..7
    s = Thaum::Select.new(items: (0..9).map(&:to_s), cursor: 7)
    s.render(canvas: canvas, theme: theme)
    assert_equal "3", buffer.row_text(y: 0).strip
    assert_equal "7", buffer.row_text(y: 4).strip
  end

  def test_does_not_scroll_when_cursor_in_view
    s = Thaum::Select.new(items: (0..9).map(&:to_s), cursor: 2)
    s.render(canvas: canvas, theme: theme)
    assert_equal "0", buffer.row_text(y: 0).strip
    assert_equal "4", buffer.row_text(y: 4).strip
  end
end
