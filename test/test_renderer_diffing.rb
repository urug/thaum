# frozen_string_literal: true

require "test_helper"

class TestRendererDiffing < Minitest::Test
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

  def reset_output
    @output.truncate(0)
    @output.rewind
  end

  def test_second_render_of_identical_buffer_emits_no_cell_changes
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "Hello")
    @renderer.render(b)

    reset_output
    b2 = buf(width: 5, height: 1)
    canvas(b2).text(content: "Hello")
    @renderer.render(b2)

    refute_includes @output.string, "Hello", "no cells changed → no chars should be written"
  end

  def test_second_render_with_one_cell_changed_only_emits_that_cell
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "Hello")
    @renderer.render(b)

    reset_output
    b2 = buf(width: 5, height: 1)
    canvas(b2).text(content: "Hellp") # last char differs
    @renderer.render(b2)

    out = @output.string
    refute_includes out, "Hell", "unchanged prefix should not be re-emitted"
    assert_includes out, "p", "changed cell must be written"
  end

  # Regression: cells that match the previous frame but sit between two
  # changed cells in the same row must be re-emitted. Skipping them with a
  # cursor jump assumes the terminal still mirrors prev_buffer at that
  # position — a stale assumption that surfaced as ghosted swatches in
  # examples/theme_picker.rb when switching between themes that share slot
  # values (e.g. solarized_dark ↔ solarized_light).
  def test_unchanged_cell_between_changes_is_re_emitted
    b = buf(width: 5, height: 1)
    b.set(x: 0, y: 0, char: "A")
    b.set(x: 1, y: 0, char: "B")
    b.set(x: 2, y: 0, char: "C") # unchanged across frames
    b.set(x: 3, y: 0, char: "D")
    b.set(x: 4, y: 0, char: "E")
    @renderer.render(b)

    reset_output
    b2 = buf(width: 5, height: 1)
    b2.set(x: 0, y: 0, char: "X") # changed
    b2.set(x: 1, y: 0, char: "B")
    b2.set(x: 2, y: 0, char: "C") # still unchanged
    b2.set(x: 3, y: 0, char: "D")
    b2.set(x: 4, y: 0, char: "Y") # changed
    @renderer.render(b2)

    out = @output.string
    assert_includes out, "XBCDY", "must emit the full dirty span (no cursor jumps over the middle)"
  end

  def test_dimension_change_forces_full_redraw
    b = buf(width: 5, height: 1)
    canvas(b).text(content: "Hello")
    @renderer.render(b)

    reset_output
    b2 = buf(width: 6, height: 1)
    canvas(b2).text(content: "Hello!")
    @renderer.render(b2)

    assert_includes @output.string, "Hello!", "full redraw at new dimensions"
  end

  def test_style_change_alone_triggers_redraw_of_that_cell
    b = buf(width: 2, height: 1)
    b.set(x: 0, y: 0, char: "X")
    b.set(x: 1, y: 0, char: "Y")
    @renderer.render(b)

    reset_output
    b2 = buf(width: 2, height: 1)
    b2.set(x: 0, y: 0, char: "X")
    b2.set(x: 1, y: 0, char: "Y", style: Thaum::Rendering::Style.new(bold: true))
    @renderer.render(b2)

    out = @output.string
    assert_includes out, "\e[1m", "bold attribute should be emitted on style change"
    assert_includes out, "Y", "the cell with new style should be re-written"
  end
end
