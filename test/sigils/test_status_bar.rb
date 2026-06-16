# frozen_string_literal: true

require "test_helper"

class TestStatusBarWidget < Minitest::Test
  def buffer(w: 40, h: 1) = Thaum::Rendering::Buffer.new(width: w, height: h)

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def theme = Thaum::Themes::DEFAULT

  def mouse(x:, button: :left, action: :press)
    Thaum::MouseEvent.new(button: button, action: action, abs_x: x, abs_y: 0, x: x, y: 0)
  end

  # ----- Construction & state -----

  def test_not_focusable
    sb = Thaum::StatusBar.new(segments: ["Ready"])
    refute sb.focusable?
  end

  def test_default_separator
    sb = Thaum::StatusBar.new(segments: %w[A B])
    assert_equal " │ ", sb.separator
  end

  def test_custom_separator
    sb = Thaum::StatusBar.new(segments: %w[A B], separator: " | ")
    assert_equal " | ", sb.separator
  end

  # ----- Rendering -----

  def test_renders_all_segments_with_separators
    sb = Thaum::StatusBar.new(segments: %w[One Two Three])
    buf = buffer
    sb.render(canvas: canvas(buf), theme: theme)
    row = buf.row_text(y: 0)
    assert_includes row, "One"
    assert_includes row, "Two"
    assert_includes row, "Three"
    assert_includes row, "│"
  end

  def test_renders_plain_and_clickable_segments
    sb = Thaum::StatusBar.new(segments: [
                                "Plain",
                                { label: "Click", on_click: ->(_e) {} }
                              ])
    buf = buffer
    sb.render(canvas: canvas(buf), theme: theme)
    row = buf.row_text(y: 0)
    assert_includes row, "Plain"
    assert_includes row, "Click"
  end

  def test_renders_custom_separator
    sb = Thaum::StatusBar.new(segments: %w[A B], separator: " // ")
    buf = buffer
    sb.render(canvas: canvas(buf), theme: theme)
    row = buf.row_text(y: 0)
    assert_includes row, " // "
  end

  # ----- Click handling -----

  def test_left_press_in_clickable_segment_invokes_callback
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                "Plain",
                                { label: "Click", on_click: ->(e) { received << e } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    # "Plain" occupies 0..4 (5 cols), separator " │ " 5..7 (3 cols), "Click" 8..12.
    evt = mouse(x: 10)
    sb.on_mouse(evt)
    assert_equal 1, received.size
    assert_same evt, received.first
  end

  def test_left_press_in_non_clickable_segment_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                "Plain",
                                { label: "Click", on_click: ->(e) { received << e } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2)) # inside "Plain"
    assert_empty received
  end

  def test_left_press_in_separator_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "A", on_click: ->(_e) { received << :a } },
                                { label: "B", on_click: ->(_e) { received << :b } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    # "A" => cols 0..0, separator " │ " => 1..3, "B" => 4..4. x=2 is in separator.
    sb.on_mouse(mouse(x: 2))
    assert_empty received
  end

  def test_left_press_past_last_segment_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "A", on_click: ->(_e) { received << :a } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 30))
    assert_empty received
  end

  def test_right_click_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2, button: :right))
    assert_empty received
  end

  def test_scroll_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2, button: :wheel_up, action: :scroll))
    assert_empty received
  end

  def test_drag_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2, button: :left, action: :drag))
    assert_empty received
  end

  def test_release_does_nothing
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2, action: :release))
    assert_empty received
  end

  def test_mouse_events_do_not_propagate
    sb = Thaum::StatusBar.new(segments: ["Plain"])
    sb.render(canvas: canvas(buffer), theme: theme)
    emitted = []
    sb.define_singleton_method(:emit) { |e| emitted << e }
    sb.on_mouse(mouse(x: 50, button: :right))
    sb.on_mouse(mouse(x: 2))
    assert_empty emitted
  end

  def test_zero_arg_callback_accepted
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                { label: "Click", on_click: -> { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 2))
    assert_equal [:hit], received
  end

  # ----- Re-render on segments= -----

  def test_segments_assignment_requests_render
    sb = Thaum::StatusBar.new(segments: ["A"])
    rerendered = false
    sb.define_singleton_method(:request_render) { rerendered = true }
    sb.segments = %w[A B]
    assert rerendered
    assert_equal %w[A B], sb.segments
  end

  def test_segments_assignment_updates_render
    sb = Thaum::StatusBar.new(segments: ["Old"])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.segments = %w[New Pair]
    buf = buffer
    sb.render(canvas: canvas(buf), theme: theme)
    row = buf.row_text(y: 0)
    assert_includes row, "New"
    assert_includes row, "Pair"
    refute_includes row, "Old"
  end

  # ----- Click range edge cases -----

  def test_click_at_segment_start_boundary_hits_it
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                "Plain",
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    # "Plain"=0..4, sep=5..7, "Click"=8..12. x=8 is first cell of "Click".
    sb.on_mouse(mouse(x: 8))
    assert_equal [:hit], received
  end

  def test_click_at_segment_end_boundary_hits_it
    received = []
    sb = Thaum::StatusBar.new(segments: [
                                "Plain",
                                { label: "Click", on_click: ->(_e) { received << :hit } }
                              ])
    sb.render(canvas: canvas(buffer), theme: theme)
    sb.on_mouse(mouse(x: 12)) # last cell of "Click"
    assert_equal [:hit], received
  end
end
