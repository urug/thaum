# frozen_string_literal: true

require "test_helper"

class TestTick < Minitest::Test
  class TickingSigil
    include Thaum::Sigil

    attr_reader :ticks

    def initialize = (@ticks = [])
    def on_tick(event) = (@ticks << event)
  end

  class TickingApp
    include Thaum::App

    attr_reader :ticks, :order, :left, :right

    def initialize
      @left   = TickingSigil.new
      @right  = TickingSigil.new
      @ticks  = []
      @order  = []
    end

    def partition
      horizontal do
        region(width: :fill) { @left }
        region(width: :fill) { @right }
      end
    end

    def on_tick(event)
      @ticks << event
      @order << :app
    end
  end

  def setup
    @app = TickingApp.new
    @app.run_partition(rect: Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24))
    @app.wire_sigils
  end

  def test_tick_event_has_time_and_delta
    evt = Thaum::TickEvent.new(time: 1.5, delta: 0.1)
    assert_in_delta 1.5, evt.time
    assert_in_delta 0.1, evt.delta
  end

  def test_dispatch_routes_tick_to_app_first_then_leaves
    @app.left.define_singleton_method(:on_tick) do |e|
      @ticks << e
      @thaum_app.order << :left
    end
    @app.right.define_singleton_method(:on_tick) do |e|
      @ticks << e
      @thaum_app.order << :right
    end

    evt = Thaum::TickEvent.new(time: 1.0, delta: 0.1)
    Thaum::Dispatch.from_queue(app: @app, event: evt)

    assert_equal %i[app left right], @app.order
    assert_equal [evt], @app.ticks
    assert_equal [evt], @app.left.ticks
    assert_equal [evt], @app.right.ticks
  end

  def test_tick_does_not_set_dirty_by_default
    refute @app.dirty?
    Thaum::Dispatch.from_queue(app: @app, event: Thaum::TickEvent.new(time: 1.0, delta: 0.1))
    refute @app.dirty?, "tick alone should not request render"
  end

  def test_tick_handler_can_request_render
    @app.define_singleton_method(:on_tick) { |_e| request_render }
    Thaum::Dispatch.from_queue(app: @app, event: Thaum::TickEvent.new(time: 1.0, delta: 0.1))
    assert @app.dirty?
  end
end
