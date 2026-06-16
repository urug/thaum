# frozen_string_literal: true

require "test_helper"
require "stringio"

class TestEmitGuards < Minitest::Test
  class EmitFromUpdateSigil
    include Thaum::Sigil

    UserEvent = Thaum::Event.define(:val)

    def on_update(_context)
      emit UserEvent.new(val: 1)
    end
  end

  class GuardApp
    include Thaum::App

    attr_reader :sigil

    def initialize
      @sigil = EmitFromUpdateSigil.new
    end

    def partition
      vertical { region(height: :fill) { @sigil } }
    end

    def on_event(_event); end
  end

  def setup
    @app = GuardApp.new
    @app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    @app.wire_sigils
  end

  def test_emit_from_on_update_raises
    assert_raises(Thaum::EmitFromUpdateError) do
      @app.update_context({})
    end
  end

  def test_emit_outside_on_update_does_not_raise
    # baseline: emitting outside on_update works
    @app.sigil.emit(EmitFromUpdateSigil::UserEvent.new(val: 2))
  end

  def test_emit_tick_event_from_sigil_warns_and_drops
    received = []
    @app.define_singleton_method(:on_event) { |e| received << e }

    captured = capture_stderr do
      @app.sigil.emit(Thaum::TickEvent.new(time: 1.0, delta: 0.1))
    end

    assert_match(/TickEvent/, captured)
    assert_empty received
  end

  def test_emit_resize_event_from_sigil_warns_and_drops
    received = []
    @app.define_singleton_method(:on_event) { |e| received << e }

    captured = capture_stderr do
      @app.sigil.emit(Thaum::ResizeEvent.new(width: 10, height: 10))
    end

    assert_match(/ResizeEvent/, captured)
    assert_empty received
  end

  private

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
