# frozen_string_literal: true

module Thaum
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
          Thaum::Action.pool.post { new.public_send(name, *args, **kwargs) }
        end
      end
    end
  end
end
