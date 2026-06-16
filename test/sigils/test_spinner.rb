# frozen_string_literal: true

require "test_helper"

class TestSpinnerWidget < Minitest::Test
  def tick(delta) = Thaum::TickEvent.new(time: 0.0, delta: delta)
  def buffer(w: 4, h: 1) = Thaum::Rendering::Buffer.new(width: w, height: h)

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def theme = Thaum::Themes::DEFAULT

  def test_default_frame_is_zero
    assert_equal 0, Thaum::Spinner.new.frame
  end

  def test_default_frames_have_more_than_one_element
    assert_operator Thaum::Spinner.new.frames.length, :>, 1
  end

  def test_focusable_is_false
    refute Thaum::Spinner.new.focusable?
  end

  def test_tick_below_interval_does_not_advance
    s = Thaum::Spinner.new(interval: 0.1)
    s.on_tick(tick(0.05))
    assert_equal 0, s.frame
  end

  def test_tick_at_or_above_interval_advances
    s = Thaum::Spinner.new(interval: 0.1)
    s.on_tick(tick(0.1))
    assert_equal 1, s.frame
  end

  def test_tick_accumulates_remainder
    s = Thaum::Spinner.new(interval: 0.1)
    s.on_tick(tick(0.07))
    s.on_tick(tick(0.05))  # cumulative 0.12 → one advance, 0.02 left
    assert_equal 1, s.frame
    s.on_tick(tick(0.08))  # cumulative 0.10 → another advance
    assert_equal 2, s.frame
  end

  def test_frame_wraps
    s = Thaum::Spinner.new(frames: %w[a b c], interval: 0.1)
    3.times { s.on_tick(tick(0.1)) }
    assert_equal 0, s.frame
  end

  def test_large_delta_advances_multiple_frames
    s = Thaum::Spinner.new(frames: %w[a b c d], interval: 0.1)
    s.on_tick(tick(0.35))
    assert_equal 3, s.frame
  end

  def test_render_writes_current_frame
    s = Thaum::Spinner.new(frames: %w[X Y], interval: 0.1)
    buf = buffer
    s.render(canvas: canvas(buf), theme: theme)
    assert_equal "X", buf.row_text(y: 0)[0]
    s.on_tick(tick(0.1))
    s.render(canvas: canvas(buf), theme: theme)
    assert_equal "Y", buf.row_text(y: 0)[0]
  end
end
