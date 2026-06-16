# frozen_string_literal: true

module Thaum
  module Rendering
    Cell = Data.define(:char, :style) do
      def initialize(char: " ", style: Style.new)
        super
      end
    end
  end
end
