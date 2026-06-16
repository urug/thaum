# frozen_string_literal: true

require "test_helper"

class TestStyle < Minitest::Test
  def test_default_attributes
    style = Thaum::Rendering::Style.new
    assert_nil style.fg
    assert_nil style.bg
    assert_equal false, style.bold
    assert_equal false, style.italic
    assert_equal false, style.underline
    assert_equal false, style.dim
  end
end
