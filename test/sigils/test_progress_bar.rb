# frozen_string_literal: true

require "test_helper"

class TestProgressBarWidget < Minitest::Test
  def buffer(w: 10, h: 1) = Thaum::Rendering::Buffer.new(width: w, height: h)

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def theme = Thaum::Themes::DEFAULT

  def tick(delta) = Thaum::TickEvent.new(time: 0.0, delta: delta)

  def filled_cells(buf:, y: 0)
    (0...buf.width).count { |x| buf.cell(x: x, y: y).style.bg == theme.accent }
  end

  def test_focusable_is_false
    refute Thaum::ProgressBar.new.focusable?
  end

  def test_zero_value_renders_no_filled_cells
    bar = Thaum::ProgressBar.new(value: 0.0)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal 0, filled_cells(buf: buf)
  end

  def test_full_value_fills_all_cells
    bar = Thaum::ProgressBar.new(value: 1.0)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal buf.width, filled_cells(buf: buf)
  end

  def test_half_value_fills_half
    bar = Thaum::ProgressBar.new(value: 0.5)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal 5, filled_cells(buf: buf)
  end

  def test_value_clamps_below_zero
    bar = Thaum::ProgressBar.new(value: -0.5)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal 0, filled_cells(buf: buf)
  end

  def test_value_clamps_above_one
    bar = Thaum::ProgressBar.new(value: 1.5)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal buf.width, filled_cells(buf: buf)
  end

  def test_value_is_writable
    bar = Thaum::ProgressBar.new(value: 0.0)
    bar.value = 0.25
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_in_delta 2.5, filled_cells(buf: buf), 0.5 # rounds to 2 or 3
  end

  def test_indeterminate_shows_fill_during_visible_phase
    bar = Thaum::ProgressBar.new(indeterminate: true)
    buf = buffer
    # Walk the offset into the visible portion of the cycle.
    10.times { bar.on_tick(tick(0.1)) }
    bar.render(canvas: canvas(buf), theme: theme)
    cells = filled_cells(buf: buf)
    assert_operator cells, :>, 0,             "indeterminate must show fill during the visible phase"
    assert_operator cells, :<=, buf.width,    "indeterminate fill must not exceed the bar"
  end

  def test_indeterminate_does_not_use_value
    # value=1.0 would fill the whole bar in determinate mode. Indeterminate
    # ignores value, so initial frame (offset=0) shows nothing yet — the
    # block has not entered the bar.
    bar = Thaum::ProgressBar.new(indeterminate: true, value: 1.0)
    buf = buffer
    bar.render(canvas: canvas(buf), theme: theme)
    assert_equal 0, filled_cells(buf: buf), "indeterminate at offset=0 must not render any value-based fill"
  end

  def test_indeterminate_advances_on_tick
    bar = Thaum::ProgressBar.new(indeterminate: true)
    before = bar.instance_variable_get(:@offset)
    bar.on_tick(tick(0.3))
    after = bar.instance_variable_get(:@offset)
    assert_operator after, :>, before
  end

  def test_determinate_ignores_tick
    bar = Thaum::ProgressBar.new(value: 0.5)
    before = bar.instance_variable_get(:@offset)
    bar.on_tick(tick(0.3))
    after = bar.instance_variable_get(:@offset)
    assert_equal before, after
  end
end
