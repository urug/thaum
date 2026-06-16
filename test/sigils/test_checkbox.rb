# frozen_string_literal: true

require "test_helper"

class TestCheckboxWidget < Minitest::Test
  def buffer(w: 20, h: 1) = Thaum::Rendering::Buffer.new(width: w, height: h)

  def canvas(buf)
    Thaum::Rendering::Canvas.new(buffer: buf,
                                 rect: Thaum::Rect.new(x: 0, y: 0, width: buf.width, height: buf.height))
  end

  def theme = Thaum::Themes::DEFAULT
  def key(k) = Thaum::KeyEvent.new(key: k)

  # ----- State ---------------------------------------------------------

  def test_default_unchecked
    cb = Thaum::Checkbox.new
    refute cb.checked?
    refute cb.indeterminate?
  end

  def test_initial_checked_state
    cb = Thaum::Checkbox.new(checked: true)
    assert cb.checked?
  end

  def test_indeterminate_clears_when_set_via_setter
    cb = Thaum::Checkbox.new(checked: true)
    cb.indeterminate = true
    assert cb.indeterminate?
    refute cb.checked?
  end

  # ----- Keyboard ------------------------------------------------------

  def test_space_toggles_checked
    cb = Thaum::Checkbox.new
    cb.on_key(key(" "))
    assert cb.checked?
    cb.on_key(key(" "))
    refute cb.checked?
  end

  def test_enter_also_toggles
    cb = Thaum::Checkbox.new
    cb.on_key(key(:enter))
    assert cb.checked?
  end

  def test_toggling_clears_indeterminate
    cb = Thaum::Checkbox.new(indeterminate: true)
    cb.on_key(key(" "))
    refute cb.indeterminate?
    assert cb.checked?
  end

  def test_toggle_emits_changed
    cb = Thaum::Checkbox.new
    emitted = []
    cb.define_singleton_method(:emit) { |e| emitted << e }
    cb.on_key(key(" "))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::Checkbox::ChangedEvent, emitted.first
    assert emitted.first.checked
  end

  def test_unhandled_key_propagates
    cb = Thaum::Checkbox.new
    emitted = []
    cb.define_singleton_method(:emit) { |e| emitted << e }
    evt = key(:f1)
    cb.on_key(evt)
    assert_equal [evt], emitted
  end

  # ----- Render --------------------------------------------------------

  def test_render_unchecked_shows_open_box
    cb = Thaum::Checkbox.new(label: "Agree")
    buf = buffer
    cb.render(canvas: canvas(buf), theme: theme)
    assert_includes buf.row_text(y: 0), "[ ] Agree"
  end

  def test_render_checked_shows_filled_box
    cb = Thaum::Checkbox.new(checked: true, label: "Agree")
    buf = buffer
    cb.render(canvas: canvas(buf), theme: theme)
    assert_includes buf.row_text(y: 0), "[X] Agree"
  end

  def test_render_indeterminate_shows_dash
    cb = Thaum::Checkbox.new(indeterminate: true, label: "Mixed")
    buf = buffer
    cb.render(canvas: canvas(buf), theme: theme)
    assert_includes buf.row_text(y: 0), "[-] Mixed"
  end
end
