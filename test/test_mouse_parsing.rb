# frozen_string_literal: true

require "test_helper"

class TestMouseParsing < Minitest::Test
  def parse(bytes)
    Thaum::EscapeParser.parse(bytes)
  end

  # SGR mouse: ESC [ < Cb ; Cx ; Cy (M|m)
  # Cx/Cy are 1-based; we store 0-based on the event.

  def test_left_button_press
    events = parse("\e[<0;10;5M")
    assert_equal 1, events.size
    ev = events.first
    assert_instance_of Thaum::MouseEvent, ev
    assert_equal :left, ev.button
    assert_equal :press, ev.action
    assert_equal 9, ev.abs_x
    assert_equal 4, ev.abs_y
    refute ev.shift?
    refute ev.alt?
    refute ev.ctrl?
  end

  def test_left_button_release
    ev = parse("\e[<0;10;5m").first
    assert_equal :left, ev.button
    assert_equal :release, ev.action
  end

  def test_middle_button_press
    ev = parse("\e[<1;3;3M").first
    assert_equal :middle, ev.button
    assert_equal :press, ev.action
  end

  def test_right_button_press
    ev = parse("\e[<2;3;3M").first
    assert_equal :right, ev.button
    assert_equal :press, ev.action
  end

  def test_wheel_up_scroll
    ev = parse("\e[<64;5;5M").first
    assert_equal :wheel_up, ev.button
    assert_equal :scroll, ev.action
  end

  def test_wheel_down_scroll
    ev = parse("\e[<65;5;5M").first
    assert_equal :wheel_down, ev.button
    assert_equal :scroll, ev.action
  end

  def test_motion_without_button_is_dropped
    # Cb = 35 = 32 (motion) | 3 (no button). Shouldn't occur under 1002
    # tracking; if it does, the parser drops it.
    assert_empty parse("\e[<35;7;8M")
  end

  def test_drag_with_left_button
    # Cb = 32 (motion) | 0 (left)
    ev = parse("\e[<32;7;8M").first
    assert_equal :drag, ev.action
    assert_equal :left, ev.button
  end

  def test_drag_with_right_button
    # Cb = 32 (motion) | 2 (right)
    ev = parse("\e[<34;7;8M").first
    assert_equal :drag, ev.action
    assert_equal :right, ev.button
  end

  def test_shift_modifier
    ev = parse("\e[<4;1;1M").first
    assert ev.shift?
    refute ev.alt?
    refute ev.ctrl?
    assert_equal :left, ev.button
  end

  def test_alt_modifier
    ev = parse("\e[<8;1;1M").first
    assert ev.alt?
    refute ev.shift?
    refute ev.ctrl?
  end

  def test_ctrl_modifier
    ev = parse("\e[<16;1;1M").first
    assert ev.ctrl?
    refute ev.shift?
    refute ev.alt?
  end

  def test_all_modifiers_combined
    # Cb = 0 | 4 | 8 | 16 = 28 (left + shift + alt + ctrl)
    ev = parse("\e[<28;2;2M").first
    assert_equal :left, ev.button
    assert ev.shift?
    assert ev.alt?
    assert ev.ctrl?
  end

  def test_multi_event_sequence
    events = parse("\e[<0;1;1M\e[<0;1;1m")
    assert_equal 2, events.size
    assert_equal :press, events[0].action
    assert_equal :release, events[1].action
  end

  def test_mouse_event_mixed_with_keys
    events = parse("a\e[<0;3;3Mb")
    assert_equal 3, events.size
    assert_instance_of Thaum::KeyEvent, events[0]
    assert_instance_of Thaum::MouseEvent, events[1]
    assert_instance_of Thaum::KeyEvent, events[2]
    assert_equal "a", events[0].key
    assert_equal "b", events[2].key
  end

  def test_coordinates_are_zero_based
    # SGR 1;1 corresponds to abs 0,0
    ev = parse("\e[<0;1;1M").first
    assert_equal 0, ev.abs_x
    assert_equal 0, ev.abs_y
  end

  def test_default_canvas_relative_coords_equal_absolute
    # Before dispatcher localizes, x/y default to abs_x/abs_y.
    ev = parse("\e[<0;10;5M").first
    assert_equal ev.abs_x, ev.x
    assert_equal ev.abs_y, ev.y
  end
end
