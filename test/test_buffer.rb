# frozen_string_literal: true

require "test_helper"

class TestBuffer < Minitest::Test
  def test_dimensions
    buf = Thaum::Rendering::Buffer.new(width: 40, height: 10)
    assert_equal 40, buf.width
    assert_equal 10, buf.height
  end

  def test_cells_start_blank
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    cell = buf.cell(x: 2, y: 1)
    assert_equal " ", cell.char
    assert cell.style.empty?
  end

  def test_set_char
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    buf.set(x: 2, y: 1, char: "A")
    assert_equal "A", buf.cell(x: 2, y: 1).char
  end

  def test_set_with_style
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    style = Thaum::Rendering::Style.new(fg: :red, bold: true)
    buf.set(x: 2, y: 1, char: "X", style: style)
    cell = buf.cell(x: 2, y: 1)
    assert_equal "X", cell.char
    assert_equal style, cell.style
  end

  def test_row_text
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    buf.set(x: 0, y: 1, char: "H")
    buf.set(x: 1, y: 1, char: "i")
    assert_equal "Hi   ", buf.row_text(y: 1)
  end

  def test_set_out_of_bounds_is_silent
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    buf.set(x: -1, y: 0, char: "X")
    buf.set(x: 5, y: 0, char: "X")
    buf.set(x: 0, y: -1, char: "X")
    buf.set(x: 0, y: 3, char: "X")
    assert_equal "     ", buf.row_text(y: 0)
  end

  def test_cover_inside
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    assert buf.cover?(x: 0, y: 0)
    assert buf.cover?(x: 4, y: 2)
    assert buf.cover?(x: 2, y: 1)
  end

  def test_cover_outside
    buf = Thaum::Rendering::Buffer.new(width: 5, height: 3)
    refute buf.cover?(x: -1, y: 0)
    refute buf.cover?(x: 5, y: 0)
    refute buf.cover?(x: 0, y: -1)
    refute buf.cover?(x: 0, y: 3)
  end
end
