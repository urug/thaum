# frozen_string_literal: true

module Thaum
  # A 2D grid of Cells, addressed by (x:, y:) with (0, 0) at the top-left.
  module Rendering
    class Buffer
      attr_reader :width, :height
      attr_accessor :cursor

      def initialize(width:, height:)
        @width  = width
        @height = height
        @cursor = nil # [x, y] in buffer coords, or nil to hide
        # Stored row-major: @cells[y][x]. Public API takes (x:, y:) per convention,
        # but rows-of-columns makes row iteration and row_text natural.
        @cells = Array.new(height) { Array.new(width) { Cell.new } }
      end

      def cell(x:, y:)
        @cells[y][x]
      end

      def row_text(y:)
        @cells[y].map(&:char).join
      end

      def set(x:, y:, char:, style: nil)
        return unless cover?(x:, y:)

        current = @cells[y][x]
        # When both the existing and incoming chars are box-drawing glyphs,
        # merge their segments so adjacent borders form correct junctions.
        # For any other pair, the new char wins (existing behavior).
        resolved = BoxDrawing.merge(existing: current.char, incoming: char)
        @cells[y][x] = current.with(char: resolved, style: style || current.style)
      end

      def cover?(x:, y:)
        x >= 0 && x < @width && y >= 0 && y < @height
      end

      # One line per row, plain text — no ANSI sequences. Use for content
      # and layout assertions in snapshot tests.
      def to_text_snapshot
        (0...@height).map { |y| row_text(y: y) }.join("\n")
      end

      # One line per row, with inline ANSI style transitions. Each row resets
      # style at the end so rows are independent. Use for visual assertions
      # including color.
      def to_ansi_snapshot
        (0...@height).map { |y| ansi_row(y) }.join("\n")
      end

      private

      def ansi_row(y)
        out = +""
        prev = nil
        @cells[y].each do |cell|
          out << style_diff(prev: prev, style: cell.style)
          out << cell.char
          prev = cell.style
        end
        out << Seq::RESET unless prev.nil? || prev.empty?
        out
      end

      def style_diff(prev:, style:)
        return "" if prev == style

        out = +""
        out << Seq::RESET if prev && !prev.empty?
        out << Seq::BOLD      if style.bold
        out << Seq::DIM       if style.dim
        out << Seq::ITALIC    if style.italic
        out << Seq::UNDERLINE if style.underline
        out << Color.to_escape(style.fg, capability: :truecolor, base: 38) if style.fg
        out << Color.to_escape(style.bg, capability: :truecolor, base: 48) if style.bg
        out
      end
    end
  end
end
