# frozen_string_literal: true

require "test_helper"

class TestTextWidget < Minitest::Test
  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: 20, height: 5)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 5))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  def test_renders_content
    sigil = Thaum::Text.new(content: "hello")
    sigil.render(canvas: canvas, theme: theme)
    assert_equal "hello", buffer.row_text(y: 0).strip
  end

  def test_not_focusable
    refute Thaum::Text.new(content: "x").focusable?
  end

  def test_align_center
    sigil = Thaum::Text.new(content: "hi", align: :center)
    sigil.render(canvas: canvas, theme: theme)
    row = buffer.row_text(y: 0)
    # "hi" centered in 20 cols → 9 spaces + "hi" + 9 spaces
    assert_equal "hi", row.strip
    assert_operator row.index("h"), :>=, 8
  end

  def test_align_right
    sigil = Thaum::Text.new(content: "hi", align: :right)
    sigil.render(canvas: canvas, theme: theme)
    row = buffer.row_text(y: 0)
    assert_equal "hi", row.strip
    assert_equal 18, row.index("h")
  end

  def test_content_can_be_updated_after_initialize
    sigil = Thaum::Text.new(content: "before")
    sigil.content = "after"

    sigil.render(canvas: canvas, theme: theme)
    assert_equal "after", buffer.row_text(y: 0).strip
  end

  def test_content_can_be_proc
    value = "one"
    sigil = Thaum::Text.new(content: -> { value })

    sigil.render(canvas: canvas, theme: theme)
    assert_equal "one", buffer.row_text(y: 0).strip

    value = "two"
    sigil.render(canvas: canvas, theme: theme)
    assert_equal "two", buffer.row_text(y: 0).strip
  end
end
