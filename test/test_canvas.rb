# frozen_string_literal: true

require "test_helper"

class TestCanvas < Minitest::Test
  def setup
    @buf = Thaum::Rendering::Buffer.new(width: 20, height: 10)
    @canvas = Thaum::Rendering::Canvas.new(buffer: @buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 10))
  end

  def test_dimensions
    assert_equal 20, @canvas.width
    assert_equal 10, @canvas.height
  end

  def test_fill_sets_char_and_bg
    @canvas.fill(char: "─", fg: :cyan)
    assert_equal "─", @buf.cell(x: 0, y: 0).char
    assert_equal "─", @buf.cell(x: 19, y: 0).char
    assert_equal :cyan, @buf.cell(x: 0, y: 0).style.fg
  end

  def test_fill_restricted_region
    @canvas.fill(char: "X", x: 2, y: 1, width: 3, height: 2)
    assert_equal " ", @buf.cell(x: 1, y: 1).char
    assert_equal "X", @buf.cell(x: 2, y: 1).char
    assert_equal "X", @buf.cell(x: 4, y: 1).char
    assert_equal " ", @buf.cell(x: 5, y: 1).char
    assert_equal " ", @buf.cell(x: 2, y: 3).char
  end

  def test_text_writes_chars
    @canvas.text(content: "Hello", x: 2, y: 3)
    assert_equal "H", @buf.cell(x: 2, y: 3).char
    assert_equal "e", @buf.cell(x: 3, y: 3).char
    assert_equal "o", @buf.cell(x: 6, y: 3).char
  end

  def test_text_clips_at_canvas_edge
    @canvas.text(content: "A" * 25, x: 0, y: 0)
    assert_equal "A", @buf.cell(x: 19, y: 0).char
  end

  def test_text_with_fg
    @canvas.text(content: "Hi", x: 0, y: 0, fg: :green)
    assert_equal :green, @buf.cell(x: 0, y: 0).style.fg
    assert_equal :green, @buf.cell(x: 1, y: 0).style.fg
  end

  def test_text_inherits_bg_from_prior_fill
    @canvas.fill(bg: :navy)
    @canvas.text(content: "Hi", fg: :white)
    cell = @buf.cell(x: 0, y: 0).style
    assert_equal :white, cell.fg
    assert_equal :navy,  cell.bg
  end

  def test_fill_with_only_bg_preserves_existing_fg
    @canvas.fill(fg: :red)
    @canvas.fill(bg: :blue)
    cell = @buf.cell(x: 0, y: 0).style
    assert_equal :red,  cell.fg
    assert_equal :blue, cell.bg
  end

  def test_text_with_only_bg_preserves_existing_fg
    @canvas.fill(fg: :red)
    @canvas.text(content: "x", bg: :blue)
    cell = @buf.cell(x: 0, y: 0).style
    assert_equal :red,  cell.fg
    assert_equal :blue, cell.bg
  end

  # --- Border ---

  def test_border_default_is_single
    inner = @canvas.border(fg: :white)
    assert_equal "┌", @buf.cell(x: 0,  y: 0).char
    assert_equal "┐", @buf.cell(x: 19, y: 0).char
    assert_equal "└", @buf.cell(x: 0,  y: 9).char
    assert_equal "┘", @buf.cell(x: 19, y: 9).char
    assert_equal "─", @buf.cell(x: 1,  y: 0).char
    assert_equal "│", @buf.cell(x: 0,  y: 1).char
    assert_equal 18, inner.width
    assert_equal 8,  inner.height
  end

  def test_border_rounded_style
    @canvas.border(style: :rounded)
    assert_equal "╭", @buf.cell(x: 0,  y: 0).char
    assert_equal "╮", @buf.cell(x: 19, y: 0).char
    assert_equal "╰", @buf.cell(x: 0,  y: 9).char
    assert_equal "╯", @buf.cell(x: 19, y: 9).char
  end

  def test_border_double_style
    @canvas.border(style: :double)
    assert_equal "╔", @buf.cell(x: 0, y: 0).char
    assert_equal "═", @buf.cell(x: 1, y: 0).char
    assert_equal "║", @buf.cell(x: 0, y: 1).char
  end

  def test_border_thick_style
    @canvas.border(style: :thick)
    assert_equal "┏", @buf.cell(x: 0, y: 0).char
    assert_equal "━", @buf.cell(x: 1, y: 0).char
    assert_equal "┃", @buf.cell(x: 0, y: 1).char
  end

  def test_border_ascii_style
    @canvas.border(style: :ascii)
    assert_equal "+", @buf.cell(x: 0,  y: 0).char
    assert_equal "-", @buf.cell(x: 1,  y: 0).char
    assert_equal "|", @buf.cell(x: 0,  y: 1).char
    assert_equal "+", @buf.cell(x: 19, y: 9).char
  end

  def test_border_dashed_style
    @canvas.border(style: :dashed)
    assert_equal "┌", @buf.cell(x: 0, y: 0).char
    assert_equal "╌", @buf.cell(x: 1, y: 0).char
    assert_equal "╎", @buf.cell(x: 0, y: 1).char
  end

  def test_border_dotted_style
    @canvas.border(style: :dotted)
    assert_equal "┌", @buf.cell(x: 0, y: 0).char
    assert_equal "┈", @buf.cell(x: 1, y: 0).char
    assert_equal "┊", @buf.cell(x: 0, y: 1).char
  end

  def test_border_applies_fg
    @canvas.border(fg: :red)
    assert_equal :red, @buf.cell(x: 0, y: 0).style.fg
  end

  def test_border_inner_canvas_can_write
    inner = @canvas.border
    inner.text(content: "X")
    assert_equal "X", @buf.cell(x: 1, y: 1).char
  end

  def test_border_raises_on_unknown_style
    assert_raises(ArgumentError) { @canvas.border(style: :bogus) }
  end

  def test_border_on_tiny_canvas_does_not_blow_up
    tiny_canvas = Thaum::Rendering::Canvas.new(buffer: @buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 1, height: 1))
    inner = tiny_canvas.border
    refute_nil inner # just shouldn't raise
  end

  def test_cursor_translates_local_to_absolute
    sub = @canvas.sub(rect: Thaum::Rect.new(x: 5, y: 3, width: 4, height: 2))
    sub.cursor(x: 1, y: 0)
    assert_equal [6, 3], @buf.cursor
  end

  def test_row_sub_canvas
    row = @canvas.row(3)
    assert_equal 1,  row.height
    assert_equal 20, row.width
    row.text(content: "hi")
    assert_equal "h", @buf.cell(x: 0, y: 3).char
  end

  def test_row_out_of_bounds_returns_nil
    assert_nil @canvas.row(10)
    assert_nil @canvas.row(-1)
  end

  def test_inset
    inner = @canvas.inset(1)
    assert_equal 18, inner.width
    assert_equal 8,  inner.height
    inner.text(content: "X")
    assert_equal "X", @buf.cell(x: 1, y: 1).char
    assert_equal " ", @buf.cell(x: 0, y: 0).char
  end

  def test_sub_canvas_clips_writes
    sub = @canvas.sub(rect: Thaum::Rect.new(x: 5, y: 2, width: 4, height: 3))
    sub.fill(char: "Z")
    assert_equal "Z", @buf.cell(x: 5, y: 2).char
    assert_equal "Z", @buf.cell(x: 8, y: 4).char
    assert_equal " ", @buf.cell(x: 9, y: 2).char
    assert_equal " ", @buf.cell(x: 5, y: 5).char
  end

  def test_canvas_offset_into_buffer
    buf = Thaum::Rendering::Buffer.new(width: 20, height: 10)
    canvas = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 5, y: 3, width: 10, height: 4))
    canvas.text(content: "Hi", x: 0, y: 0)
    assert_equal "H", buf.cell(x: 5, y: 3).char
    assert_equal " ", buf.cell(x: 4, y: 3).char
  end

  def test_text_centers_wide_chars_by_display_width
    @canvas.text(content: "日本語", y: 0, align: :center)
    # display_width == 6, canvas width 20 → start at (20-6)/2 = 7
    assert_equal "日", @buf.cell(x: 7, y: 0).char
    assert_equal "",  @buf.cell(x: 8, y: 0).char
    assert_equal "本", @buf.cell(x: 9, y: 0).char
    assert_equal "",  @buf.cell(x: 10, y: 0).char
    assert_equal "語", @buf.cell(x: 11, y: 0).char
    assert_equal "",  @buf.cell(x: 12, y: 0).char
  end

  def test_text_advances_past_wide_chars
    @canvas.text(content: "日x", x: 0, y: 0)
    assert_equal "日", @buf.cell(x: 0, y: 0).char
    assert_equal "",  @buf.cell(x: 1, y: 0).char
    assert_equal "x", @buf.cell(x: 2, y: 0).char
  end

  def test_text_right_aligns_by_display_width
    @canvas.text(content: "日", y: 0, align: :right)
    assert_equal "日", @buf.cell(x: 18, y: 0).char
    assert_equal "",  @buf.cell(x: 19, y: 0).char
  end

  def test_measure_reports_display_width
    result = @canvas.measure(content: "日本語")
    assert_equal 6, result[:width]
    assert_equal 1, result[:height]
  end
end
