# frozen_string_literal: true

require "test_helper"

class TestButtonWidget < Minitest::Test
  def buffer = @buffer ||= Thaum::Rendering::Buffer.new(width: 10, height: 1)

  def canvas
    @canvas ||= Thaum::Rendering::Canvas.new(buffer: buffer,
                                             rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 1))
  end

  def theme = @theme ||= Thaum::Themes::DEFAULT

  # --- State ---

  def test_label_and_default_state
    b = Thaum::Button.new(label: "OK")
    assert_equal "OK", b.label
    refute b.disabled?
    assert b.focusable?
  end

  def test_disabled_button_is_not_focusable
    b = Thaum::Button.new(label: "OK", disabled: true)
    assert b.disabled?
    refute b.focusable?
  end

  # --- Activation ---

  def test_enter_emits_pressed_with_label
    b = Thaum::Button.new(label: "Save")
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_equal 1, emitted.size
    assert_instance_of Thaum::Button::PressedEvent, emitted.first
    assert_equal "Save", emitted.first.label
  end

  def test_space_emits_pressed
    b = Thaum::Button.new(label: "OK")
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: " "))
    assert_instance_of Thaum::Button::PressedEvent, emitted.first
  end

  def test_disabled_does_not_emit_on_enter
    b = Thaum::Button.new(label: "OK", disabled: true)
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_empty emitted
  end

  def test_unhandled_key_propagates
    b = Thaum::Button.new(label: "OK")
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    evt = Thaum::KeyEvent.new(key: :f1)
    b.on_key(evt)
    assert_equal [evt], emitted
  end

  # --- Rendering ---

  def test_renders_label_centered
    b = Thaum::Button.new(label: "Hi")
    b.render(canvas: canvas, theme: theme)
    row = buffer.row_text(y: 0)
    assert_equal "Hi", row.strip
  end

  def test_renders_with_accent_fg_when_focused
    b = Thaum::Button.new(label: "Hi")
    b.define_singleton_method(:focused?) { true }
    b.render(canvas: canvas, theme: theme)
    assert_equal theme.accent, buffer.cell(x: 4, y: 0).style.fg
  end

  def test_renders_with_dim_fg_when_disabled
    b = Thaum::Button.new(label: "Hi", disabled: true)
    b.render(canvas: canvas, theme: theme)
    assert_equal theme.dim, buffer.cell(x: 4, y: 0).style.fg
  end

  def test_renders_with_pressed_bg_when_focused
    b = Thaum::Button.new(label: "Hi")
    b.define_singleton_method(:focused?) { true }
    b.render(canvas: canvas, theme: theme)
    assert_equal theme.pressed, buffer.cell(x: 4, y: 0).style.bg
  end

  def test_renders_with_no_bg_when_unfocused
    b = Thaum::Button.new(label: "Hi")
    b.define_singleton_method(:focused?) { false }
    b.render(canvas: canvas, theme: theme)
    assert_nil buffer.cell(x: 4, y: 0).style.bg
  end

  def test_keyboard_activation_with_enter
    b = Thaum::Button.new(label: "Save")
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_equal 1, emitted.size
  end

  def test_keyboard_activation_with_space
    b = Thaum::Button.new(label: "Save")
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: " "))
    assert_equal 1, emitted.size
  end

  def test_disabled_does_not_activate_on_enter
    b = Thaum::Button.new(label: "OK", disabled: true)
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: :enter))
    assert_empty emitted
  end

  def test_disabled_does_not_activate_on_space
    b = Thaum::Button.new(label: "OK", disabled: true)
    emitted = []
    b.define_singleton_method(:emit) { |e| emitted << e }
    b.on_key(Thaum::KeyEvent.new(key: " "))
    assert_empty emitted
  end
end
