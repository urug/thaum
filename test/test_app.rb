# frozen_string_literal: true

require "test_helper"

class TestApp < Minitest::Test
  class Counter
    include Thaum::Sigil

    attr_reader :count, :received_context

    def initialize = (@count = 0)

    def on_key(event)
      case event.key
      when "+" then @count += 1
      when "-" then @count -= 1
      else emit(event)
      end
    end

    def on_update(context) = (@received_context = context)
  end

  class MyApp
    include Thaum::App

    attr_reader :counter, :received_key

    def initialize
      @counter = Counter.new
    end

    def partition
      vertical do
        region(height: :fill) { @counter }
      end
    end

    def on_key(event)
      @received_key = event
    end
  end

  def setup
    @app  = MyApp.new
    @rect = Thaum::Rect.new(x: 0, y: 0, width: 80, height: 24)
    @app.run_partition(rect: @rect)
    @app.wire_sigils
  end

  def test_wire_sigils_sets_thaum_app
    assert_same @app, @app.counter.thaum_app
  end

  def test_initial_focus_returns_first_focusable
    assert_same @app.counter, @app.initial_focus
  end

  def test_update_context_fires_on_update
    @app.update_context({ score: 42 })
    assert_equal({ score: 42 }, @app.counter.received_context)
  end

  def test_update_context_deep_freezes
    @app.update_context({ nested: { a: [1, 2] } })
    ctx = @app.counter.received_context
    assert ctx.frozen?
    assert ctx[:nested].frozen?
    assert ctx[:nested][:a].frozen?
  end

  def test_focus_fires_on_focus_and_on_blur
    other = Counter.new
    other.thaum_app = @app
    @app.leaf_sigils << other

    focused_calls = []
    blurred_calls = []
    @app.counter.define_singleton_method(:on_focus) { focused_calls << :focus }
    other.define_singleton_method(:on_blur) { blurred_calls << :blur }

    # Set up other as current focus so blur fires on it
    @app.instance_variable_set(:@focused_sigil, other)
    @app.focus(@app.counter)

    assert_equal [:focus], focused_calls
    assert_equal [:blur],  blurred_calls
  end

  def test_emit_from_sigil_routes_key_event_to_app_on_key
    event = Thaum::KeyEvent.new(key: :escape)
    @app.counter.emit(event)
    assert_same event, @app.received_key
  end

  def test_quit_sets_quit_flag
    refute @app.quit?
    @app.quit
    assert @app.quit?
  end

  def test_request_render_sets_dirty
    refute @app.dirty?
    @app.request_render
    assert @app.dirty?
  end

  def test_focus_next_cycles
    # Only one focusable sigil — focus_next loops back to same
    @app.focus(@app.counter)
    @app.focus_next
    assert_same @app.counter, @app.focused_sigil
  end

  def test_focus_non_focusable_is_noop
    non = Counter.new
    non.define_singleton_method(:focusable?) { false }
    @app.focus(non)
    # focus unchanged (nil since we never set it)
    assert_nil @app.focused_sigil
  end
end
