# frozen_string_literal: true

module Thaum
  class Table
    include Sigil

    SelectedEvent = Thaum::Event.define(:index, :row)

    PAGE_STEP = 10

    attr_reader :headers, :rows, :widths, :cursor, :offset

    def initialize(headers:, rows:, widths: nil)
      @headers = headers
      @rows    = rows
      @widths  = widths
      @cursor  = 0
      @offset  = 0
    end

    def on_key(event)
      case event.key
      when :up        then @cursor = [@cursor - 1, 0].max
      when :down      then @cursor = [@cursor + 1, rows.length - 1].min if rows.any?
      when :home      then @cursor = 0
      when :end       then @cursor = rows.length - 1 if rows.any?
      when :page_up   then @cursor = [@cursor - PAGE_STEP, 0].max
      when :page_down then @cursor = [@cursor + PAGE_STEP, rows.length - 1].min if rows.any?
      when :enter     then emit_selected
      else                 emit event
      end
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bg)
      widths = effective_widths(canvas.width)
      visible_offset(canvas)

      render_header(canvas: canvas, theme: theme, widths: widths)
      render_separator(canvas: canvas, theme: theme)
      render_data_rows(canvas: canvas, theme: theme, widths: widths)
    end

    private

    def emit_selected
      return if rows.empty?

      emit SelectedEvent.new(index: @cursor, row: rows[@cursor])
    end

    def render_header(canvas:, theme:, widths:)
      row = canvas.row(0) or return

      row.fill(bg: theme.bar_bg)
      row.text(content: format_cells(cells: @headers, widths: widths), fg: theme.accent, bg: theme.bar_bg)
    end

    def render_separator(canvas:, theme:)
      row = canvas.row(1) or return

      row.fill(bg: theme.bg)
      row.text(content: "─" * canvas.width, fg: theme.border, bg: theme.bg)
    end

    def render_data_rows(canvas:, theme:, widths:)
      visible_rows = canvas.height - 2
      return if visible_rows <= 0

      visible_rows.times do |i|
        file_idx = @offset + i
        row_data = rows[file_idx] or break
        row      = canvas.row(i + 2) or break

        selected = file_idx == @cursor
        bg = selected ? theme.selection : theme.bg
        fg = selected ? theme.selection_fg : theme.fg
        row.fill(bg: bg)
        row.text(content: format_cells(cells: row_data, widths: widths), fg: fg, bg: bg)
      end
    end

    def format_cells(cells:, widths:)
      cells.each_with_index.map { |cell, idx| fit(str: cell.to_s, width: widths[idx] || 0) }.join(" ")
    end

    # Pad with spaces or truncate to fit exactly `width` display columns.
    def fit(str:, width:)
      return "" if width <= 0

      w = str.display_width
      return str + (" " * (width - w)) if w <= width

      truncate_to_width(str: str, width: width)
    end

    def truncate_to_width(str:, width:)
      out  = +""
      cols = 0
      str.each_char do |c|
        cw = c.display_width
        break if cols + cw > width

        out << c
        cols += cw
      end
      out << (" " * (width - cols)) if cols < width
      out
    end

    def visible_offset(canvas)
      visible_rows = canvas.height - 2
      return @offset = 0 if visible_rows <= 0

      if @cursor < @offset
        @offset = @cursor
      elsif @cursor >= @offset + visible_rows
        @offset = @cursor - visible_rows + 1
      end

      max_offset = [rows.length - visible_rows, 0].max
      @offset = @offset.clamp(0, max_offset)
    end

    def effective_widths(canvas_width)
      return widths if widths

      col_count = headers.length
      return [] if col_count.zero?

      max_widths = column_max_widths(col_count)
      separators = col_count - 1
      total_max  = max_widths.sum
      budget     = canvas_width - separators

      return max_widths if total_max <= budget || budget <= 0

      scale_widths(max_widths: max_widths, total_max: total_max, budget: budget)
    end

    def column_max_widths(col_count)
      Array.new(col_count) do |idx|
        header_w = (headers[idx] || "").to_s.display_width
        row_w    = rows.map { |r| (r[idx] || "").to_s.display_width }.max || 0
        [header_w, row_w].max
      end
    end

    def scale_widths(max_widths:, total_max:, budget:)
      scaled = max_widths.map { |w| (budget * w / total_max).floor }
      leftover = budget - scaled.sum
      scaled[-1] += leftover if scaled.any?
      scaled
    end
  end
end
