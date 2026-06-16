# frozen_string_literal: true

require "test_helper"

class TestRenderer < Minitest::Test
  def setup
    @output = StringIO.new
    @renderer = Thaum::Rendering::Renderer.new(output: @output)
  end

  def buf(width:, height:)
    Thaum::Rendering::Buffer.new(width: width, height: height)
  end

  def canvas(buffer)
    Thaum::Rendering::Canvas.new(buffer: buffer,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buffer.width, height: buffer.height))
  end

  # --- Cursor ---

  def test_hides_cursor_when_buffer_cursor_is_nil
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "hello")
    @renderer.render(b)
    assert_includes @output.string, Thaum::Seq::CURSOR_HIDE
  end

  def test_positions_and_shows_cursor_when_set
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "hello")
    b.cursor = [2, 0]
    @renderer.render(b)
    assert_includes @output.string, Thaum::Seq.cursor_pos(x: 3, y: 1)
    assert_includes @output.string, Thaum::Seq::CURSOR_SHOW
  end

  def test_cursor_change_redraws_even_when_cells_unchanged
    b1 = buf(width: 5, height: 1)
    canvas(b1).text(content: "hello")
    b1.cursor = [1, 0]
    @renderer.render(b1)
    @output.truncate(0)
    @output.rewind

    b2 = buf(width: 5, height: 1)
    canvas(b2).text(content: "hello")
    b2.cursor = [3, 0]
    @renderer.render(b2)
    assert_includes @output.string, Thaum::Seq.cursor_pos(x: 4, y: 1)
  end

  # --- Character output ---

  def test_renders_characters
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "Hello")
    @renderer.render(b)
    assert_includes @output.string, "Hello"
  end

  def test_blank_buffer_renders_spaces
    b = buf(width: 3, height: 1)
    @renderer.render(b)
    assert_includes @output.string, "   "
  end

  # --- Cursor positioning ---

  def test_positions_first_row_at_top_left
    b = buf(width: 5, height: 1)
    @renderer.render(b)
    assert_includes @output.string, "\e[1;1H"
  end

  def test_positions_second_row_correctly
    b = buf(width: 3, height: 2)
    @renderer.render(b)
    assert_includes @output.string, "\e[2;1H"
  end

  def test_row_order_in_output
    b = buf(width: 3, height: 2)
    canvas(b).text(content: "ABC", y: 0)
    canvas(b).text(content: "XYZ", y: 1)
    @renderer.render(b)
    out = @output.string
    assert out.index("ABC") < out.index("XYZ"), "row 0 must appear before row 1"
  end

  # --- Style: text attributes ---

  def test_bold
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(bold: true))
    @renderer.render(b)
    assert_includes @output.string, "\e[1m"
  end

  def test_dim
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(dim: true))
    @renderer.render(b)
    assert_includes @output.string, "\e[2m"
  end

  def test_italic
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(italic: true))
    @renderer.render(b)
    assert_includes @output.string, "\e[3m"
  end

  def test_underline
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(underline: true))
    @renderer.render(b)
    assert_includes @output.string, "\e[4m"
  end

  # --- Style: colors ---

  def test_named_fg_color
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(fg: :red))
    @renderer.render(b)
    assert_includes @output.string, "\e[31m"
  end

  def test_named_bg_color
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(bg: :blue))
    @renderer.render(b)
    assert_includes @output.string, "\e[44m"
  end

  def test_bright_fg_color
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(fg: :bright_cyan))
    @renderer.render(b)
    assert_includes @output.string, "\e[96m"
  end

  def test_hex_fg_color
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(fg: "#ff6b6b"))
    @renderer.render(b)
    assert_includes @output.string, "\e[38;2;255;107;107m"
  end

  def test_hex_bg_color
    b = buf(width: 1, height: 1)
    b.set(x: 0, y: 0, char: "X", style: Thaum::Rendering::Style.new(bg: "#1e1e2e"))
    @renderer.render(b)
    assert_includes @output.string, "\e[48;2;30;30;46m"
  end

  # --- Style transitions ---

  def test_resets_after_styled_cell_before_plain_cell
    b = buf(width: 2, height: 1)
    b.set(x: 0, y: 0, char: "A", style: Thaum::Rendering::Style.new(bold: true))
    b.set(x: 1, y: 0, char: "B")
    @renderer.render(b)
    out   = @output.string
    b_pos = out.index("B")
    assert out.index("\e[1m"), "bold sequence must be present"
    assert out[0...b_pos].include?("\e[0m"), "reset must appear before the unstyled char"
  end

  def test_no_redundant_reset_for_all_plain_cells
    b = buf(width: 3, height: 1)
    @renderer.render(b)
    resets = @output.string.scan("\e[0m").size
    assert resets <= 1, "plain buffer should have at most 1 reset (trailing), got #{resets}"
  end
end
