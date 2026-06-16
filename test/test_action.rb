# frozen_string_literal: true

require "test_helper"

class TestAction < Minitest::Test
  ResultLoadedEvent = Thaum::Event.define(:value)

  def setup
    @queue = Thread::Queue.new
    @prev_queue = Thaum::Action.queue
    @prev_pool  = Thaum::Action.pool
    Thaum::Action.queue = @queue
    Thaum::Action.pool  = Concurrent::ImmediateExecutor.new
  end

  def teardown
    Thaum::Action.queue = @prev_queue
    Thaum::Action.pool  = @prev_pool
  end

  class Fetcher
    include Thaum::Action

    def fetch(value)
      emit ResultLoadedEvent.new(value: value * 2)
    end

    private

    def helper; end
  end

  def test_public_instance_method_becomes_class_method
    assert_respond_to Fetcher, :fetch
  end

  def test_private_instance_method_does_not_become_class_method
    refute_respond_to Fetcher, :helper
  end

  def test_initialize_does_not_become_class_method
    refute_respond_to Fetcher, :new_initialize
    # `initialize` is special — the framework must not generate a class method for it
    # Class.new is unaffected; we only check that calling .initialize on the class doesn't go through Action's path.
    refute Fetcher.singleton_class.method_defined?(:initialize, false)
  end

  def test_class_method_invokes_instance_method_on_pool
    Fetcher.fetch(21)
    evt = @queue.pop
    assert_instance_of ResultLoadedEvent, evt
    assert_equal 42, evt.value
  end

  def test_each_invocation_creates_new_instance
    klass = Class.new do
      include Thaum::Action

      define_method(:run) do |store|
        store << object_id
      end
    end

    seen = []
    klass.run(seen)
    klass.run(seen)
    assert_equal 2, seen.size
    refute_equal seen[0], seen[1], "actions should not share instances across calls"
  end

  def test_emit_with_no_queue_set_is_noop
    Thaum::Action.queue = nil
    # Should not raise
    Fetcher.new.send(:emit, ResultLoadedEvent.new(value: 1))
  end
end
