# frozen_string_literal: true

module Thaum
  module Event
    def self.define(*attrs, &block)
      Data.define(*attrs) do
        include Thaum::Event

        class_eval(&block) if block
      end
    end
  end
end
