# frozen_string_literal: true

module Thaum
  module Rendering
    Style = Data.define(:fg, :bg, :bold, :italic, :underline, :dim) do
      def initialize(fg: nil, bg: nil, bold: false, italic: false, underline: false, dim: false)
        super
      end

      def empty? = !fg && !bg && !bold && !italic && !underline && !dim
    end
  end
end
