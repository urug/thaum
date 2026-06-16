# frozen_string_literal: true

require "test_helper"

class TestStyledRuns < Minitest::Test
  def setup
    @buffer = Thaum::Rendering::Buffer.new(width: 40, height: 3)
    @canvas = Thaum::Rendering::Canvas.new(buffer: @buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 40, height: 3))
  end

  def test_styled_runs_render_concatenated_chars
    @canvas.text(content: [
                   ["AB", Thaum::Rendering::Style.new(fg: :red, bold: true)],
                   ["CD", Thaum::Rendering::Style.new(fg: :blue)]
                 ])
    assert_equal "ABCD", @buffer.row_text(y: 0)[0, 4]
  end

  def test_styled_runs_apply_each_runs_style
    @canvas.text(content: [
                   ["A", Thaum::Rendering::Style.new(fg: :red, bold: true)],
                   ["B", Thaum::Rendering::Style.new(fg: :blue, italic: true)]
                 ])
    a = @buffer.cell(x: 0, y: 0).style
    b = @buffer.cell(x: 1, y: 0).style
    assert_equal :red, a.fg
    assert a.bold
    refute a.italic
    assert_equal :blue, b.fg
    refute b.bold
    assert b.italic
  end

  def test_styled_runs_truncate_at_canvas_edge
    narrow = Thaum::Rendering::Canvas.new(buffer: @buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 3, height: 1))
    narrow.text(content: [
                  ["AA", Thaum::Rendering::Style.new(fg: :red)],
                  ["BBBB", Thaum::Rendering::Style.new(fg: :blue)]
                ])
    # Width is 3 — should write "AAB" then stop
    assert_equal "AAB", @buffer.row_text(y: 0)[0, 3]
  end

  def test_styled_runs_respect_align_right
    canvas = Thaum::Rendering::Canvas.new(buffer: @buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 1))
    canvas.text(
      content: [
        ["AB", Thaum::Rendering::Style.new(fg: :red)],
        ["CD", Thaum::Rendering::Style.new(fg: :blue)]
      ],
      align: :right
    )
    # Total run width = 4, canvas width = 10 → start at x=6
    assert_equal "#{' ' * 6}ABCD", @buffer.row_text(y: 0)[0, 10]
  end

  def test_styled_runs_respect_align_center
    canvas = Thaum::Rendering::Canvas.new(buffer: @buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 1))
    canvas.text(
      content: [
        ["AB", Thaum::Rendering::Style.new(fg: :red)],
        ["CD", Thaum::Rendering::Style.new(fg: :blue)]
      ],
      align: :center
    )
    # Total = 4, canvas = 10 → padding 3 left, 3 right
    assert_equal "#{' ' * 3}ABCD#{' ' * 3}", @buffer.row_text(y: 0)[0, 10]
  end

  def test_string_content_still_works
    @canvas.text(content: "hello", fg: :green)
    assert_equal "hello", @buffer.row_text(y: 0)[0, 5]
    assert_equal :green, @buffer.cell(x: 0, y: 0).style.fg
  end
end
