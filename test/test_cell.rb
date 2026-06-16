# frozen_string_literal: true

require "test_helper"

class TestCell < Minitest::Test
  def test_default_attributes
    cell = Thaum::Rendering::Cell.new
    assert_equal " ", cell.char
    assert_equal Thaum::Rendering::Style.new, cell.style
    assert cell.style.empty?
  end

  def test_carries_style
    style = Thaum::Rendering::Style.new(fg: :red, bold: true)
    cell  = Thaum::Rendering::Cell.new(char: "X", style: style)
    assert_equal "X", cell.char
    assert_equal style, cell.style
  end
end
