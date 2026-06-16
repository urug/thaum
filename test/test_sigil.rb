# frozen_string_literal: true

require "test_helper"

class TestSigil < Minitest::Test
  class MySigil
    include Thaum::Sigil
  end

  def setup
    @sigil = MySigil.new
  end

  def test_focusable_default
    assert @sigil.focusable?
  end

  def test_focused_without_app
    refute @sigil.focused?
  end

  def test_responds_to_render
    assert_respond_to @sigil, :render
  end

  def test_responds_to_lifecycle_handlers
    %i[on_mount on_unmount on_focus on_blur on_update on_tick].each do |m|
      assert_respond_to @sigil, m
    end
  end

  def test_responds_to_terminal_handlers
    %i[on_key on_mouse on_paste].each { |m| assert_respond_to @sigil, m }
  end

  def test_render_is_noop_by_default
    buffer = Thaum::Rendering::Buffer.new(width: 10, height: 5)
    canvas = Thaum::Rendering::Canvas.new(buffer: buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 10, height: 5))
    assert_nil @sigil.render(canvas: canvas, theme: Thaum::Themes::DEFAULT)
  end

  def test_emit_without_app_is_noop
    event = Thaum::KeyEvent.new(key: "a")
    assert_nil @sigil.emit(event)
  end

  def test_emit_routes_to_app
    dispatched = []
    fake_app = Object.new
    fake_app.define_singleton_method(:dispatch_from_child) { |e| dispatched << e }
    fake_app.define_singleton_method(:focused_sigil) { nil }
    fake_app.define_singleton_method(:in_on_update) { false }

    @sigil.thaum_app = fake_app
    event = Thaum::KeyEvent.new(key: "x")
    @sigil.emit(event)

    assert_equal [event], dispatched
  end

  def test_focused_with_app
    sigil    = @sigil
    fake_app = Object.new
    fake_app.define_singleton_method(:focused_sigil) { sigil }

    @sigil.thaum_app = fake_app
    assert @sigil.focused?
  end

  def test_on_key_default_calls_emit
    emitted = []
    @sigil.define_singleton_method(:emit) { |e| emitted << e }
    event = Thaum::KeyEvent.new(key: "a")
    @sigil.on_key(event)
    assert_equal [event], emitted
  end
end
