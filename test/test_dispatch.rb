# frozen_string_literal: true

require "test_helper"

class TestDispatch < Minitest::Test
  FakeEvent = Thaum::Event.define(:payload)

  class CaptureSigil
    include Thaum::Sigil
  end

  class CaptureApp
    include Thaum::App

    attr_reader :events_received, :keys_received, :pastes_received, :resizes_received, :sigil

    def initialize
      @sigil           = CaptureSigil.new
      @events_received = []
      @keys_received   = []
      @pastes_received = []
      @resizes_received = []
    end

    def partition
      vertical { region(height: :fill) { @sigil } }
    end

    def on_event(event)  = (@events_received << event)
    def on_key(event)    = (@keys_received << event)
    def on_paste(event)  = (@pastes_received << event)
    def on_resize(event) = (@resizes_received << event)
  end

  def setup
    @app = CaptureApp.new
    @app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    @app.wire_sigils
  end

  def test_dispatch_event_routes_user_event_to_on_event
    evt = FakeEvent.new(payload: 42)
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    assert_equal [evt], @app.events_received
  end

  def test_dispatch_event_routes_key_event_when_no_focus
    evt = Thaum::KeyEvent.new(key: "q")
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    assert_equal [evt], @app.keys_received
  end

  def test_dispatch_event_routes_key_event_to_focused_sigil
    received = []
    @app.sigil.define_singleton_method(:on_key) { |e| received << e }
    @app.instance_variable_set(:@focused_sigil, @app.sigil)

    evt = Thaum::KeyEvent.new(key: "q")
    Thaum::Dispatch.from_queue(app: @app, event: evt)

    assert_equal [evt], received
    assert_empty @app.keys_received
  end

  def test_ctrl_c_quits_app_without_dispatch
    evt = Thaum::KeyEvent.new(key: "c", ctrl: true)
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    assert @app.quit?
    assert_empty @app.keys_received
  end

  def test_ctrl_c_quits_even_when_sigil_is_focused
    received = []
    @app.sigil.define_singleton_method(:on_key) { |e| received << e }
    @app.instance_variable_set(:@focused_sigil, @app.sigil)

    evt = Thaum::KeyEvent.new(key: "c", ctrl: true)
    Thaum::Dispatch.from_queue(app: @app, event: evt)

    assert @app.quit?
    assert_empty received
  end

  def test_plain_c_still_dispatches_normally
    evt = Thaum::KeyEvent.new(key: "c")
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    refute @app.quit?
    assert_equal [evt], @app.keys_received
  end

  def test_other_ctrl_combos_still_dispatch
    evt = Thaum::KeyEvent.new(key: "a", ctrl: true)
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    refute @app.quit?
    assert_equal [evt], @app.keys_received
  end

  def test_dispatch_event_routes_paste_event_when_no_focus
    evt = Thaum::PasteEvent.new(text: "hello")
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    assert_equal [evt], @app.pastes_received
  end

  def test_dispatch_event_routes_paste_event_to_focused_sigil
    received = []
    @app.sigil.define_singleton_method(:on_paste) { |e| received << e }
    @app.instance_variable_set(:@focused_sigil, @app.sigil)

    evt = Thaum::PasteEvent.new(text: "hi")
    Thaum::Dispatch.from_queue(app: @app, event: evt)

    assert_equal [evt], received
    assert_empty @app.pastes_received
  end

  def test_dispatch_event_routes_resize_event_to_app_only
    evt = Thaum::ResizeEvent.new(width: 100, height: 30)
    Thaum::Dispatch.from_queue(app: @app, event: evt)
    assert_equal [evt], @app.resizes_received
  end

  def test_dispatch_event_sets_dirty_flag
    refute @app.dirty?
    Thaum::Dispatch.from_queue(app: @app, event: FakeEvent.new(payload: 1))
    assert @app.dirty?
  end

  def test_dispatch_event_unknown_object_is_silently_ignored
    Thaum::Dispatch.from_queue(app: @app, event: Object.new)
    assert_empty @app.events_received
    assert_empty @app.keys_received
  end
end
