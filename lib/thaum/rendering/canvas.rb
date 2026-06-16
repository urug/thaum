# frozen_string_literal: true

module Thaum
  # A rectangular view into a Buffer that translates local coordinates to buffer coordinates.
  module Rendering
    class Canvas
      BORDERS = {
        single:  { tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│" },
        rounded: { tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│" },
        double:  { tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║" },
        thick:   { tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃" },
        # Dashed + dotted reuse the light corner glyphs — Unicode does not
        # define dashed corners. The horizontal/vertical runs use 2-dash
        # (dashed) or 4-dash (dotted, denser-looking) light glyphs.
        dashed:  { tl: "┌", tr: "┐", bl: "└", br: "┘", h: "╌", v: "╎" },
        dotted:  { tl: "┌", tr: "┐", bl: "└", br: "┘", h: "┈", v: "┊" },
        ascii:   { tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|" }
      }.freeze

      attr_reader :rect

      def initialize(buffer:, rect:)
        @buffer = buffer
        @rect   = rect
      end

      def x      = @rect.x
      def y      = @rect.y
      def width  = @rect.width
      def height = @rect.height

      def fill(char: " ", fg: nil, bg: nil, x: 0, y: 0, width: @rect.width, height: @rect.height)
        height.times do |dy|
          width.times do |dx|
            cx = @rect.x + x + dx
            cy = @rect.y + y + dy
            @buffer.set(x: cx, y: cy, char: char, style: blend_style(cx: cx, cy: cy, fg: fg, bg: bg))
          end
        end
      end

      def text(content:, fg: nil, bg: nil, x: 0, y: 0, align: :left, wrap: :none, **_opts)
        if content.is_a?(Array)
          draw_styled_runs(runs: content, x: x, y: y, align: align)
        else
          draw_string_text(content: content.to_s, x: x, y: y, align: align, wrap: wrap, fg: fg, bg: bg)
        end
      end

      def cursor(x:, y:)
        @buffer.cursor = [@rect.x + x, @rect.y + y]
      end

      # Draws a box around the perimeter and returns the inset canvas (w-2 × h-2)
      # so callers can render contents inside. style is one of BORDERS' keys.
      def border(fg: nil, bg: nil, style: :single)
        chars = BORDERS.fetch(style) { raise ArgumentError, "unknown border style: #{style.inspect}" }
        return inset(1) if @rect.width < 2 || @rect.height < 2

        draw_border(chars: chars, fg: fg, bg: bg)
        inset(1)
      end

      def measure(content:, wrap: :none, width: @rect.width)
        lines = wrap == :none ? [content.to_s] : wrap_lines(text: content.to_s, width: width)
        { width: lines.map(&:display_width).max || 0, height: lines.size }
      end

      def row(n)
        return nil if n.negative? || n >= @rect.height

        child_canvas(Rect.new(x: @rect.x, y: @rect.y + n, width: @rect.width, height: 1))
      end

      # rect is in local coordinates (relative to this canvas's origin).
      def sub(rect:)
        child_canvas(Rect.new(x: @rect.x + rect.x, y: @rect.y + rect.y, width: rect.width, height: rect.height))
      end

      def top(n)
        child_canvas(Rect.new(x: @rect.x, y: @rect.y, width: @rect.width, height: [n, @rect.height].min))
      end

      def bottom(n)
        child_canvas(Rect.new(x: @rect.x, y: @rect.y + @rect.height - n, width: @rect.width,
                              height: [n, @rect.height].min))
      end

      def left(n)
        child_canvas(Rect.new(x: @rect.x, y: @rect.y, width: [n, @rect.width].min, height: @rect.height))
      end

      def right(n)
        child_canvas(Rect.new(x: @rect.x + @rect.width - n, y: @rect.y, width: [n, @rect.width].min,
                              height: @rect.height))
      end

      def inset(n_or_opts)
        if n_or_opts.is_a?(Integer)
          n = n_or_opts
          child_canvas(Rect.new(x: @rect.x + n, y: @rect.y + n, width: @rect.width - (n * 2),
                                height: @rect.height - (n * 2)))
        else
          t = n_or_opts[:top]    || 0
          r = n_or_opts[:right]  || 0
          b = n_or_opts[:bottom] || 0
          l = n_or_opts[:left]   || 0
          child_canvas(Rect.new(x: @rect.x + l, y: @rect.y + t, width: @rect.width - l - r,
                                height: @rect.height - t - b))
        end
      end

      private

      def child_canvas(rect) = Canvas.new(buffer: @buffer, rect: rect)

      def draw_border(chars:, fg:, bg:)
        w = @rect.width
        h = @rect.height
        top = "#{chars[:tl]}#{chars[:h] * (w - 2)}#{chars[:tr]}"
        bot = "#{chars[:bl]}#{chars[:h] * (w - 2)}#{chars[:br]}"
        text(content: top, y: 0,     fg: fg, bg: bg)
        text(content: bot, y: h - 1, fg: fg, bg: bg)
        (1..(h - 2)).each do |row_y|
          text(content: chars[:v], x: 0,     y: row_y, fg: fg, bg: bg)
          text(content: chars[:v], x: w - 1, y: row_y, fg: fg, bg: bg)
        end
      end

      def draw_string_text(content:, x:, y:, align:, wrap:, fg:, bg:)
        lines = wrap == :none ? [content] : wrap_lines(text: content, width: @rect.width - x)
        right_edge = @rect.x + @rect.width

        lines.each_with_index do |line, dy|
          row_y = y + dy
          break if row_y >= @rect.height

          bx = align_offset(line: line, available_width: @rect.width, align: align, x: x)
          line.each_char do |char|
            w = char.display_width
            break if bx + w > right_edge

            cy    = @rect.y + row_y
            style = blend_style(cx: bx, cy: cy, fg: fg, bg: bg)
            @buffer.set(x: bx,     y: cy, char: char, style: style)
            @buffer.set(x: bx + 1, y: cy, char: "",   style: style) if w == 2
            bx += w
          end
        end
      end

      # Compose a Style by overlaying explicitly-set fg/bg onto the cell's
      # current style. nil means "inherit." This makes layered draws compose:
      # fill bg, then text fg, keeps bg. Per DECISIONS.md 2026-06-10.
      def blend_style(cx:, cy:, fg:, bg:)
        return nil if fg.nil? && bg.nil?
        return Style.new(fg: fg, bg: bg) unless @buffer.cover?(x: cx, y: cy)

        existing = @buffer.cell(x: cx, y: cy).style
        existing.with(fg: fg || existing.fg, bg: bg || existing.bg)
      end

      def draw_styled_runs(runs:, x:, y:, align:)
        return if y >= @rect.height

        total_w = runs.sum { |str, _style| str.display_width }
        bx = case align
             when :center then @rect.x + [(@rect.width - total_w) / 2, 0].max
             when :right  then @rect.x + [@rect.width - total_w, 0].max
             else              @rect.x + x
             end
        row_y = @rect.y + y
        right_edge = @rect.x + @rect.width

        runs.each do |str, style|
          str.each_char do |char|
            w = char.display_width
            break if bx + w > right_edge

            @buffer.set(x: bx, y: row_y, char: char, style: style)
            @buffer.set(x: bx + 1, y: row_y, char: "", style: style) if w == 2
            bx += w
          end
          break if bx >= right_edge
        end
      end

      def align_offset(line:, available_width:, align:, x:)
        case align
        when :center then @rect.x + [(available_width - line.display_width) / 2, 0].max
        when :right  then @rect.x + [available_width - line.display_width, 0].max
        else              @rect.x + x # :left
        end
      end

      def wrap_lines(text:, width:)
        return [text] if width <= 0

        lines = []
        text.each_line(chomp: true) do |para|
          words = para.split
          line  = +""
          words.each do |word|
            if line.empty?
              line << word
            elsif line.display_width + 1 + word.display_width <= width
              line << " " << word
            else
              lines << line
              line = +word
            end
          end
          lines << line
        end
        lines.empty? ? [""] : lines
      end
    end
  end
end
