# frozen_string_literal: true

require "test_helper"

class TestTableWidget < Minitest::Test
  WIDTH  = 30
  HEIGHT = 8

  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: WIDTH, height: HEIGHT)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: WIDTH, height: HEIGHT))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  def headers = %w[Name Age City]

  def rows
    [
      %w[Alice 30 NYC],
      %w[Bob 25 LA],
      %w[Charlie 40 SF]
    ]
  end

  def make(extra = {})
    Thaum::Table.new(headers: headers, rows: rows, **extra)
  end

  # --- State ---

  def test_default_cursor_and_offset_are_zero
    t = make
    assert_equal 0, t.cursor
    assert_equal 0, t.offset
  end

  def test_exposes_headers_rows_widths
    t = Thaum::Table.new(headers: headers, rows: rows, widths: [8, 4, 6])
    assert_equal headers, t.headers
    assert_equal rows, t.rows
    assert_equal [8, 4, 6], t.widths
  end

  # --- Navigation ---

  def test_down_advances_cursor
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :down))
    assert_equal 1, t.cursor
  end

  def test_down_clamps_at_last_row
    t = make
    3.times { t.on_key(Thaum::KeyEvent.new(key: :down)) }
    assert_equal 2, t.cursor
  end

  def test_up_retreats_cursor
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :down))
    t.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 0, t.cursor
  end

  def test_up_clamps_at_zero
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 0, t.cursor
  end

  def test_home_jumps_to_first
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :down))
    t.on_key(Thaum::KeyEvent.new(key: :down))
    t.on_key(Thaum::KeyEvent.new(key: :home))
    assert_equal 0, t.cursor
  end

  def test_end_jumps_to_last
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :end))
    assert_equal 2, t.cursor
  end

  def test_end_noop_on_empty_rows
    t = Thaum::Table.new(headers: headers, rows: [])
    t.on_key(Thaum::KeyEvent.new(key: :end))
    assert_equal 0, t.cursor
  end

  def test_page_down_jumps_by_page_step
    big_rows = (0..49).map { |i| [i.to_s, i.to_s, i.to_s] }
    t = Thaum::Table.new(headers: headers, rows: big_rows)
    t.on_key(Thaum::KeyEvent.new(key: :page_down))
    assert_equal 10, t.cursor
  end

  def test_page_down_clamps_to_last
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :page_down))
    assert_equal 2, t.cursor
  end

  def test_page_up_jumps_by_page_step
    big_rows = (0..49).map { |i| [i.to_s, i.to_s, i.to_s] }
    t = Thaum::Table.new(headers: headers, rows: big_rows)
    t.on_key(Thaum::KeyEvent.new(key: :end))
    t.on_key(Thaum::KeyEvent.new(key: :page_up))
    assert_equal 39, t.cursor
  end

  def test_page_up_clamps_at_zero
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :page_up))
    assert_equal 0, t.cursor
  end

  # --- Selection ---

  def test_enter_emits_selected_with_index_and_row
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :down))
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    t.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::Table::SelectedEvent, emitted.first
    assert_equal 1, emitted.first.index
    assert_equal %w[Bob 25 LA], emitted.first.row
  end

  def test_enter_with_empty_rows_does_not_emit
    t = Thaum::Table.new(headers: headers, rows: [])
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    t.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_empty emitted
  end

  def test_unhandled_key_propagates
    t = make
    emitted = []
    t.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::KeyEvent.new(key: :f1)
    t.on_key(evt)
    assert_equal [evt], emitted
  end

  # --- Rendering ---

  def test_header_row_contains_all_header_text
    t = make
    t.render(canvas: canvas, theme: theme)
    line = buffer.row_text(y: 0)
    assert_includes line, "Name"
    assert_includes line, "Age"
    assert_includes line, "City"
  end

  def test_separator_row_is_full_of_dashes
    t = make
    t.render(canvas: canvas, theme: theme)
    line = buffer.row_text(y: 1)
    assert_equal "─" * WIDTH, line
  end

  def test_data_rows_contain_row_content
    t = make
    t.render(canvas: canvas, theme: theme)
    assert_includes buffer.row_text(y: 2), "Alice"
    assert_includes buffer.row_text(y: 3), "Bob"
    assert_includes buffer.row_text(y: 4), "Charlie"
  end

  def test_selected_row_has_selection_background
    t = make
    t.on_key(Thaum::KeyEvent.new(key: :down))
    t.render(canvas: canvas, theme: theme)
    assert_equal theme.selection, buffer.cell(x: 0, y: 3).style.bg
    refute_equal theme.selection, buffer.cell(x: 0, y: 2).style.bg
  end

  def test_header_uses_bar_bg
    t = make
    t.render(canvas: canvas, theme: theme)
    assert_equal theme.bar_bg, buffer.cell(x: 0, y: 0).style.bg
  end

  def test_scroll_keeps_cursor_visible_when_below_window
    # 8-row canvas: 2 chrome (header+sep) + 6 data rows visible.
    # 20 rows, cursor at 15 → offset becomes 15 - 6 + 1 = 10, last visible row = 15
    big_rows = (0..19).map { |i| ["row#{i}", i.to_s, "x"] }
    t = Thaum::Table.new(headers: headers, rows: big_rows)
    15.times { t.on_key(Thaum::KeyEvent.new(key: :down)) }
    t.render(canvas: canvas, theme: theme)
    assert_equal 10, t.offset
    assert_includes buffer.row_text(y: 2), "row10"
    assert_includes buffer.row_text(y: 7), "row15"
  end

  def test_scroll_keeps_cursor_visible_when_above_window
    big_rows = (0..19).map { |i| ["row#{i}", i.to_s, "x"] }
    t = Thaum::Table.new(headers: headers, rows: big_rows)
    # push to row 15 then back to 2 — offset should follow up
    15.times { t.on_key(Thaum::KeyEvent.new(key: :down)) }
    t.render(canvas: canvas, theme: theme)
    13.times { t.on_key(Thaum::KeyEvent.new(key: :up)) }
    t.render(canvas: canvas, theme: theme)
    assert_equal 2, t.cursor
    assert_equal 2, t.offset
    assert_includes buffer.row_text(y: 2), "row2"
  end

  def test_explicit_widths_are_honored
    # Narrow first column truncates "Charlie" (7 cols) to 3
    t = Thaum::Table.new(headers: headers, rows: rows, widths: [3, 2, 4])
    t.render(canvas: canvas, theme: theme)
    # "Charlie" cell appears on y=4 truncated to "Cha"
    line = buffer.row_text(y: 4)
    assert_includes line, "Cha"
    refute_includes line, "Charlie"
  end

  def test_explicit_widths_pad_narrower_content
    # Wide first column pads short cells
    t = Thaum::Table.new(headers: headers, rows: rows, widths: [10, 4, 6])
    t.render(canvas: canvas, theme: theme)
    line = buffer.row_text(y: 3)
    # "Bob" padded to 10 cols then " " separator then "25"
    assert_match(/Bob {7} {1}25/, line)
  end

  def test_auto_widths_fit_within_canvas_width
    # Build a wide table that needs scaling
    wide_rows = [
      %w[AAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBB CCCCCCCCCCCCCCCC]
    ]
    t = Thaum::Table.new(headers: %w[H1 H2 H3], rows: wide_rows)
    t.render(canvas: canvas, theme: theme)
    line = buffer.row_text(y: 2)
    # The rendered cells + 2 separator spaces must fit within WIDTH
    assert_operator line.display_width, :<=, WIDTH
  end

  def test_empty_rows_renders_header_and_separator_without_error
    t = Thaum::Table.new(headers: headers, rows: [])
    t.render(canvas: canvas, theme: theme)
    assert_includes buffer.row_text(y: 0), "Name"
    assert_equal "─" * WIDTH, buffer.row_text(y: 1)
  end
end
