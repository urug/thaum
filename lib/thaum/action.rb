# frozen_string_literal: true

module Thaum
  # Mixin that turns a plain class into a background "action".
  #
  # Including this module promotes every *public* instance method into a
  # class method (see {ClassMethods#method_added}). Calling that class method
  # schedules the work on the run loop's background thread pool:
  #
  #   - A fresh instance is built with an argless `new`, so Actions must not
  #     require constructor arguments.
  #   - The method runs fire-and-forget; its return value is discarded.
  #   - Use {#emit} to push results back to the run loop as events.
  #   - Calling a promoted method outside a running Thaum app (no pool) raises
  #     {Thaum::Error}.
  module Action
    class << self
      attr_accessor :queue, :pool
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def emit(event)
      Thaum::Action.queue&.push(event)
    end

    module ClassMethods
      def method_added(name)
        super
        return if name == :initialize
        return unless public_method_defined?(name)
        return if singleton_class.method_defined?(name, false)

        define_singleton_method(name) do |*args, **kwargs|
          pool = Thaum::Action.pool
          unless pool
            raise Thaum::Error,
                  "Thaum::Action method called outside a running Thaum app (no thread pool available)"
          end

          pool.post { new.public_send(name, *args, **kwargs) }
        end
      end
    end
  end
end
