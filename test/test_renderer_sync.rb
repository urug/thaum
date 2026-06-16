# frozen_string_literal: true

require "test_helper"

class TestRendererSync < Minitest::Test
  def setup
    @output = StringIO.new
    @renderer = Thaum::Rendering::Renderer.new(output: @output)
  end

  def buf(width:, height:)
    Thaum::Rendering::Buffer.new(width: width, height: height)
  end

  def reset_output
    @output.truncate(0)
    @output.rewind
  end

  def test_render_wraps_in_sync_begin_and_end
    b = buf(width: 2, height: 1)
    @renderer.render(b)
    out = @output.string
    assert out.start_with?("\e[?2026h"), "expected sync begin at start, got: #{out.inspect}"
    assert out.end_with?("\e[?2026l"),   "expected sync end at end, got: #{out.inspect}"
  end

  def test_no_diff_render_emits_nothing
    b = buf(width: 2, height: 1)
    @renderer.render(b)
    reset_output

    b2 = buf(width: 2, height: 1)
    @renderer.render(b2)
    assert_empty @output.string, "identical render should be a no-op, not even sync escapes"
  end
end
