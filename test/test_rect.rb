# frozen_string_literal: true

require "test_helper"

class TestRect < Minitest::Test
  def test_attributes
    rect = Thaum::Rect.new(x: 5, y: 3, width: 20, height: 10)
    assert_equal 5,  rect.x
    assert_equal 3,  rect.y
    assert_equal 20, rect.width
    assert_equal 10, rect.height
  end
end
