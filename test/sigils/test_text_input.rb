# frozen_string_literal: true

require "test_helper"

class TestTextInputWidget < Minitest::Test
  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: 10, height: 1)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 1))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  def input(**)
    @input ||= Thaum::TextInput.new(**)
  end

  # --- State ---

  def test_default_value_is_empty
    assert_equal "", input.value
    assert_equal 0, input.cursor
  end

  def test_initial_value_sets_value_and_places_cursor_at_end
    i = Thaum::TextInput.new(value: "hello")
    assert_equal "hello", i.value
    assert_equal 5, i.cursor
  end

  # --- Editing ---

  def test_printable_key_inserts_at_cursor
    input.on_key(Thaum::KeyEvent.new(key: "a"))
    input.on_key(Thaum::KeyEvent.new(key: "b"))
    assert_equal "ab", input.value
    assert_equal 2, input.cursor
  end

  def test_backspace_deletes_char_before_cursor
    i = Thaum::TextInput.new(value: "abc")
    i.on_key(Thaum::KeyEvent.new(key: :backspace))
    assert_equal "ab", i.value
    assert_equal 2, i.cursor
  end

  def test_backspace_at_start_is_noop
    i = Thaum::TextInput.new(value: "abc")
    i.instance_variable_set(:@cursor, 0)
    i.on_key(Thaum::KeyEvent.new(key: :backspace))
    assert_equal "abc", i.value
    assert_equal 0, i.cursor
  end

  def test_delete_removes_char_at_cursor
    i = Thaum::TextInput.new(value: "abc")
    i.instance_variable_set(:@cursor, 1)
    i.on_key(Thaum::KeyEvent.new(key: :delete))
    assert_equal "ac", i.value
    assert_equal 1, i.cursor
  end

  def test_delete_at_end_is_noop
    i = Thaum::TextInput.new(value: "abc")
    i.on_key(Thaum::KeyEvent.new(key: :delete))
    assert_equal "abc", i.value
    assert_equal 3, i.cursor
  end

  # --- Navigation ---

  def test_left_arrow_moves_cursor_back
    i = Thaum::TextInput.new(value: "abc")
    i.on_key(Thaum::KeyEvent.new(key: :left))
    assert_equal 2, i.cursor
  end

  def test_left_at_start_is_clamped
    i = Thaum::TextInput.new(value: "abc")
    i.instance_variable_set(:@cursor, 0)
    i.on_key(Thaum::KeyEvent.new(key: :left))
    assert_equal 0, i.cursor
  end

  def test_right_arrow_moves_cursor_forward
    i = Thaum::TextInput.new(value: "abc")
    i.instance_variable_set(:@cursor, 1)
    i.on_key(Thaum::KeyEvent.new(key: :right))
    assert_equal 2, i.cursor
  end

  def test_right_at_end_is_clamped
    i = Thaum::TextInput.new(value: "abc")
    i.on_key(Thaum::KeyEvent.new(key: :right))
    assert_equal 3, i.cursor
  end

  def test_home_moves_to_start
    i = Thaum::TextInput.new(value: "abc")
    i.on_key(Thaum::KeyEvent.new(key: :home))
    assert_equal 0, i.cursor
  end

  def test_end_moves_to_end
    i = Thaum::TextInput.new(value: "abc")
    i.instance_variable_set(:@cursor, 0)
    i.on_key(Thaum::KeyEvent.new(key: :end))
    assert_equal 3, i.cursor
  end

  # --- Clear ---

  def test_clear_resets_value_and_cursor
    i = Thaum::TextInput.new(value: "hello")
    i.clear
    assert_equal "", i.value
    assert_equal 0, i.cursor
  end

  def test_clear_allows_further_editing
    i = Thaum::TextInput.new(value: "hello")
    i.clear
    i.on_key(Thaum::KeyEvent.new(key: "x"))
    assert_equal "x", i.value
    assert_equal 1, i.cursor
  end

  # --- Submit ---

  def test_enter_emits_submitted_event_with_value
    i = Thaum::TextInput.new(value: "hello")
    emitted = []
    i.define_singleton_method(:emit) { |e| emitted << e }
    i.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::TextInput::SubmittedEvent, emitted.first
    assert_equal "hello", emitted.first.value
  end

  def test_unhandled_key_propagates
    emitted = []
    input.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::KeyEvent.new(key: :f1)
    input.on_key(evt)
    assert_equal [evt], emitted
  end

  # --- Rendering ---

  def test_renders_value
    i = Thaum::TextInput.new(value: "hi")
    i.render(canvas: canvas, theme: theme)
    assert_equal "hi", buffer.row_text(y: 0).strip
  end

  def test_cursor_directive_only_when_focused
    i = Thaum::TextInput.new(value: "ab")
    cursor_calls = []
    canvas.define_singleton_method(:cursor) { |**kw| cursor_calls << kw }

    i.render(canvas: canvas, theme: theme)
    assert_empty cursor_calls, "cursor should not be set when unfocused"

    i.define_singleton_method(:focused?) { true }
    i.render(canvas: canvas, theme: theme)
    refute_empty cursor_calls
    assert_equal 2, cursor_calls.last[:x]
    assert_equal 0, cursor_calls.last[:y]
  end

  # --- Horizontal scroll ---

  def test_long_value_scrolls_so_cursor_is_visible
    long = "abcdefghijklmno" # 15 chars in a 10-wide canvas
    i = Thaum::TextInput.new(value: long)
    i.render(canvas: canvas, theme: theme)
    # Cursor at index 15 (one past last char). Scroll puts cursor at col 9 (the
    # right edge), so visible window is value[6..14] = "ghijklmno" + empty cell.
    row = buffer.row_text(y: 0)
    assert_equal "ghijklmno ", row
  end

  def test_cursor_at_zero_does_not_scroll
    long = "abcdefghijklmno"
    i = Thaum::TextInput.new(value: long)
    i.instance_variable_set(:@cursor, 0)
    i.render(canvas: canvas, theme: theme)
    row = buffer.row_text(y: 0)
    assert_equal "abcdefghij", row
  end

  # --- Unicode display width ---

  def test_cursor_column_uses_display_width_for_cjk
    i = Thaum::TextInput.new(value: "あ") # 1 char, 2 display cols, cursor at end (1)
    i.define_singleton_method(:focused?) { true }
    cursor_calls = []
    canvas.define_singleton_method(:cursor) { |**kw| cursor_calls << kw }
    i.render(canvas: canvas, theme: theme)
    assert_equal 2, cursor_calls.last[:x], "cursor must land after wide char"
  end

  def test_cursor_column_uses_display_width_for_emoji
    i = Thaum::TextInput.new(value: "😀hi") # cursor at 3; cols = 2+1+1 = 4
    i.define_singleton_method(:focused?) { true }
    cursor_calls = []
    canvas.define_singleton_method(:cursor) { |**kw| cursor_calls << kw }
    i.render(canvas: canvas, theme: theme)
    assert_equal 4, cursor_calls.last[:x]
  end

  def test_wide_chars_render_in_visible_window
    # 4 CJK chars × 2 cols = 8 cols; fits inside width-10 canvas with room for cursor
    i = Thaum::TextInput.new(value: "あいうえ")
    i.render(canvas: canvas, theme: theme)
    # Canvas writes a placeholder cell after each wide char (per framework convention)
    assert_equal "あいうえ", buffer.row_text(y: 0).gsub(" ", "")
  end

  def test_scroll_offset_is_column_based_for_wide_chars
    # 6 CJK chars × 2 cols = 12 cols; canvas is 10. Cursor at end (char idx 6).
    # Need cursor at col 9 → drop one leading char (2 cols) → offset=1, visible cols=10.
    i = Thaum::TextInput.new(value: "あいうえおか")
    i.define_singleton_method(:focused?) { true }
    cursor_calls = []
    canvas.define_singleton_method(:cursor) { |**kw| cursor_calls << kw }
    i.render(canvas: canvas, theme: theme)
    # visible should start from "い" — leading "あ" scrolled off
    row = buffer.row_text(y: 0)
    refute_includes row, "あ"
    assert_includes row, "か"
    # cursor at col after the last wide char's pair of cells in the visible window
    assert cursor_calls.last[:x] <= 9, "cursor must stay within canvas width"
  end

  def test_insert_wide_char_advances_cursor_by_one_char_index
    i = Thaum::TextInput.new
    i.on_key(Thaum::KeyEvent.new(key: "あ"))
    assert_equal "あ", i.value
    assert_equal 1, i.cursor, "cursor is a character index, not a column"
  end
end
