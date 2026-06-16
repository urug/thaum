# frozen_string_literal: true

require "test_helper"

class TestScrollViewWidget < Minitest::Test
  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: 20, height: 5)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  # --- State ---

  def test_default_state
    sv = Thaum::ScrollView.new
    assert_equal 0, sv.offset_y
    assert_equal 0, sv.offset_x
    assert_equal [], sv.rows
  end

  def test_accepts_initial_rows
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    assert_equal %w[a b c], sv.rows
  end

  def test_rows_setter_clamps_offset_y_when_shrinking
    sv = Thaum::ScrollView.new(rows: (0..20).map(&:to_s))
    20.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    assert_equal 20, sv.offset_y
    sv.rows = %w[only one two]
    assert_operator sv.offset_y, :<=, 2
  end

  def test_rows_setter_clamps_offset_x_when_shrinking
    sv = Thaum::ScrollView.new(rows: ["x" * 30])
    10.times { sv.on_key(Thaum::KeyEvent.new(key: :right)) }
    assert_equal 10, sv.offset_x
    sv.rows = ["abc"]
    assert_operator sv.offset_x, :<=, 2
  end

  def test_rows_setter_resets_offset_y_when_empty
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    sv.on_key(Thaum::KeyEvent.new(key: :down))
    sv.rows = []
    assert_equal 0, sv.offset_y
  end

  # --- Vertical navigation ---

  def test_down_advances_offset_y
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    sv.on_key(Thaum::KeyEvent.new(key: :down))
    assert_equal 1, sv.offset_y
  end

  def test_down_clamps_at_last_row
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    10.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    assert_equal 2, sv.offset_y
  end

  def test_up_retreats_offset_y
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    sv.on_key(Thaum::KeyEvent.new(key: :down))
    sv.on_key(Thaum::KeyEvent.new(key: :down))
    sv.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 1, sv.offset_y
  end

  def test_up_clamps_at_zero
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    sv.on_key(Thaum::KeyEvent.new(key: :up))
    assert_equal 0, sv.offset_y
  end

  def test_page_down_jumps_by_ten
    sv = Thaum::ScrollView.new(rows: (0..30).map(&:to_s))
    sv.on_key(Thaum::KeyEvent.new(key: :page_down))
    assert_equal 10, sv.offset_y
  end

  def test_page_up_jumps_by_ten
    sv = Thaum::ScrollView.new(rows: (0..30).map(&:to_s))
    15.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    sv.on_key(Thaum::KeyEvent.new(key: :page_up))
    assert_equal 5, sv.offset_y
  end

  def test_home_goes_to_zero
    sv = Thaum::ScrollView.new(rows: (0..10).map(&:to_s))
    5.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    sv.on_key(Thaum::KeyEvent.new(key: :home))
    assert_equal 0, sv.offset_y
  end

  def test_end_goes_to_last_row
    sv = Thaum::ScrollView.new(rows: (0..10).map(&:to_s))
    sv.on_key(Thaum::KeyEvent.new(key: :end))
    assert_equal 10, sv.offset_y
  end

  # --- Horizontal navigation ---

  def test_right_advances_offset_x
    sv = Thaum::ScrollView.new(rows: ["hello world"])
    sv.on_key(Thaum::KeyEvent.new(key: :right))
    assert_equal 1, sv.offset_x
  end

  def test_right_clamps_at_max_content_width
    sv = Thaum::ScrollView.new(rows: ["abc"])
    20.times { sv.on_key(Thaum::KeyEvent.new(key: :right)) }
    assert_equal 2, sv.offset_x
  end

  def test_right_with_empty_rows_stays_at_zero
    sv = Thaum::ScrollView.new
    sv.on_key(Thaum::KeyEvent.new(key: :right))
    assert_equal 0, sv.offset_x
  end

  def test_left_retreats_offset_x
    sv = Thaum::ScrollView.new(rows: ["hello world"])
    3.times { sv.on_key(Thaum::KeyEvent.new(key: :right)) }
    sv.on_key(Thaum::KeyEvent.new(key: :left))
    assert_equal 2, sv.offset_x
  end

  def test_left_clamps_at_zero
    sv = Thaum::ScrollView.new(rows: ["hello"])
    sv.on_key(Thaum::KeyEvent.new(key: :left))
    assert_equal 0, sv.offset_x
  end

  # --- Unhandled key ---

  def test_unhandled_key_propagates
    sv = Thaum::ScrollView.new(rows: %w[a b])
    emitted = []
    sv.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::KeyEvent.new(key: :f1)
    sv.on_key(evt)
    assert_equal [evt], emitted
  end

  # --- Mouse wheel ---

  def wheel(button:, x: 0, y: 0)
    Thaum::MouseEvent.new(button: button, action: :scroll, abs_x: x, abs_y: y)
  end

  def test_wheel_down_advances_offset_y_by_step
    sv = Thaum::ScrollView.new(rows: (0..20).map(&:to_s))
    sv.on_mouse(wheel(button: :wheel_down))
    assert_equal Thaum::ScrollView::WHEEL_STEP, sv.offset_y
  end

  def test_wheel_up_retreats_offset_y_by_step
    sv = Thaum::ScrollView.new(rows: (0..20).map(&:to_s))
    sv.on_mouse(wheel(button: :wheel_down))
    sv.on_mouse(wheel(button: :wheel_down))
    sv.on_mouse(wheel(button: :wheel_up))
    assert_equal Thaum::ScrollView::WHEEL_STEP, sv.offset_y
  end

  def test_wheel_up_clamps_at_zero
    sv = Thaum::ScrollView.new(rows: (0..20).map(&:to_s))
    sv.on_mouse(wheel(button: :wheel_up))
    assert_equal 0, sv.offset_y
  end

  def test_wheel_down_clamps_at_last_row
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    10.times { sv.on_mouse(wheel(button: :wheel_down)) }
    assert_equal 2, sv.offset_y
  end

  def test_non_wheel_mouse_event_propagates
    sv = Thaum::ScrollView.new(rows: %w[a b])
    emitted = []
    sv.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::MouseEvent.new(button: :left, action: :press, abs_x: 1, abs_y: 1)
    sv.on_mouse(evt)
    assert_equal [evt], emitted
  end

  # --- Render ---

  def test_renders_rows_at_offset_y_zero
    sv = Thaum::ScrollView.new(rows: %w[alpha beta gamma])
    sv.render(canvas: canvas, theme: theme)
    assert_equal "alpha", buffer.row_text(y: 0).strip
    assert_equal "beta",  buffer.row_text(y: 1).strip
    assert_equal "gamma", buffer.row_text(y: 2).strip
  end

  def test_renders_rows_starting_from_offset_y
    sv = Thaum::ScrollView.new(rows: %w[a b c d e f g h])
    2.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    sv.render(canvas: canvas, theme: theme)
    assert_equal "c", buffer.cell(x: 0, y: 0).char
    assert_equal "d", buffer.cell(x: 0, y: 1).char
    assert_equal "g", buffer.cell(x: 0, y: 4).char
  end

  def test_rows_above_offset_y_are_not_visible
    sv = Thaum::ScrollView.new(rows: %w[a b c d e f g h i j])
    3.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    sv.render(canvas: canvas, theme: theme)
    # offset_y = 3, canvas height 5, 10 rows → first visible row is "d".
    visible_chars = (0...canvas.height).map { |y| buffer.cell(x: 0, y: y).char }
    refute_includes visible_chars, "a"
    refute_includes visible_chars, "b"
    refute_includes visible_chars, "c"
    assert_includes visible_chars, "d"
  end

  def test_only_canvas_height_rows_visible
    sv = Thaum::ScrollView.new(rows: (0..20).map { |i| "row#{i}" })
    sv.render(canvas: canvas, theme: theme)
    # Canvas is 5 tall; rows row0..row4 should be visible (last row may include indicator).
    assert_equal "row0", buffer.row_text(y: 0).strip
    assert buffer.row_text(y: 4).start_with?("row4"), "expected row 4 to start with row4"
  end

  def test_offset_x_slices_columns
    sv = Thaum::ScrollView.new(rows: ["abcdefghij"])
    2.times { sv.on_key(Thaum::KeyEvent.new(key: :right)) }
    sv.render(canvas: canvas, theme: theme)
    assert_equal "cdefghij", buffer.row_text(y: 0).strip
  end

  def test_top_indicator_when_scrolled_down
    sv = Thaum::ScrollView.new(rows: (0..20).map { |i| "r#{i}" })
    sv.on_key(Thaum::KeyEvent.new(key: :down))
    sv.render(canvas: canvas, theme: theme)
    assert_equal "▲", buffer.cell(x: canvas.width - 1, y: 0).char
  end

  def test_bottom_indicator_when_more_rows_below
    sv = Thaum::ScrollView.new(rows: (0..20).map { |i| "r#{i}" })
    sv.render(canvas: canvas, theme: theme)
    assert_equal "▼", buffer.cell(x: canvas.width - 1, y: canvas.height - 1).char
  end

  def test_no_indicators_when_content_fits
    sv = Thaum::ScrollView.new(rows: %w[a b c])
    sv.render(canvas: canvas, theme: theme)
    refute_equal "▲", buffer.cell(x: canvas.width - 1, y: 0).char
    refute_equal "▼", buffer.cell(x: canvas.width - 1, y: canvas.height - 1).char
  end

  def test_per_canvas_clamp_adjusts_offset_y_when_too_large
    sv = Thaum::ScrollView.new(rows: %w[a b c d e f g])
    # 7 rows, canvas 5 tall → max offset_y for full page is 2.
    # Push offset_y to 6 via on_key (which uses rows.length - 1 = 6 as ceiling)
    10.times { sv.on_key(Thaum::KeyEvent.new(key: :down)) }
    assert_equal 6, sv.offset_y
    sv.render(canvas: canvas, theme: theme)
    assert_equal 2, sv.offset_y
  end

  def test_cjk_row_offset_x_drops_wide_char_cleanly
    sv = Thaum::ScrollView.new(rows: ["あいうえお"])
    2.times { sv.on_key(Thaum::KeyEvent.new(key: :right)) }
    sv.render(canvas: canvas, theme: theme)
    # "あ" is 2 cols wide; offset_x=2 should drop it, starting with い.
    text = buffer.row_text(y: 0)
    assert text.start_with?("い"), "expected row to start with い, got #{text.inspect}"
  end
end
