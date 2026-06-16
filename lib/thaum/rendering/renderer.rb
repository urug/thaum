# frozen_string_literal: true

module Thaum
  # Renders a Buffer to a terminal output stream using ANSI escape sequences.
  module Rendering
    class Renderer
      def initialize(output: $stdout, capability: :truecolor)
        @output = output
        @out = +""
        @prev_buffer = nil
        @capability = capability
      end

      def render(buffer)
        @out.clear
        full_redraw = @prev_buffer.nil? ||
                      @prev_buffer.width != buffer.width ||
                      @prev_buffer.height != buffer.height
        prev_style = nil
        any_writes = false

        buffer.height.times do |y|
          if full_redraw
            first_x = 0
            last_x  = buffer.width - 1
          else
            first_x, last_x = dirty_span(buffer: buffer, y: y)
            next unless first_x
          end

          # Emit the full span between the first and last dirty cells. Skipping
          # unchanged cells inside the span and jumping the cursor over them
          # would leave their on-screen state untouched, which is only safe if
          # the terminal really mirrors prev_buffer at those positions. When
          # consecutive themes share slot values, that assumption produces the
          # bug where swatches keep stale pixels across transitions.
          @out << Seq.cursor_pos(x: first_x + 1, y: y + 1)
          (first_x..last_x).each do |x|
            cell = buffer.cell(x: x, y: y)
            emit_style(style: cell.style, prev: prev_style)
            @out << cell.char
            prev_style = cell.style
          end
          any_writes = true
        end

        @out << Seq::RESET if any_writes

        emit_cursor(buffer: buffer, full_redraw: full_redraw)

        @prev_buffer = buffer
        return if @out.empty?

        @output.write(Seq::SYNC_BEGIN, @out, Seq::SYNC_END)
        @output.flush
      end

      private

      def dirty_span(buffer:, y:)
        first = nil
        last  = nil
        buffer.width.times do |x|
          next if buffer.cell(x: x, y: y) == @prev_buffer.cell(x: x, y: y)

          first ||= x
          last = x
        end
        [first, last]
      end

      def emit_cursor(buffer:, full_redraw:)
        prev = @prev_buffer&.cursor
        curr = buffer.cursor
        return unless full_redraw || prev != curr

        if curr
          @out << Seq.cursor_pos(x: curr[0] + 1, y: curr[1] + 1) << Seq::CURSOR_SHOW
        else
          @out << Seq::CURSOR_HIDE
        end
      end

      def emit_style(style:, prev:)
        return if prev && style == prev

        @out << Seq::RESET if prev && !prev.empty?

        @out << Seq::BOLD      if style.bold
        @out << Seq::DIM       if style.dim
        @out << Seq::ITALIC    if style.italic
        @out << Seq::UNDERLINE if style.underline
        @out << Color.to_escape(style.fg, capability: @capability, base: 38) if style.fg
        @out << Color.to_escape(style.bg, capability: @capability, base: 48) if style.bg
      end
    end
  end
end
