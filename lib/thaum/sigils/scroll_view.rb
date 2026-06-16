# frozen_string_literal: true

module Thaum
  # A scrollable viewport over a list of pre-rendered text rows.
  #
  # This is the row-list variant — apps supply an Array of String rows
  # (one row per element) and ScrollView handles vertical + horizontal
  # scrolling. Long rows are sliced by display columns, so wide chars
  # (CJK, emoji) scroll cleanly.
  class ScrollView
    include Sigil

    WHEEL_STEP = 3

    attr_reader :offset_y, :offset_x, :rows

    def initialize(rows: [])
      @rows     = rows
      @offset_y = 0
      @offset_x = 0
    end

    def rows=(new_rows)
      @rows = new_rows
      @offset_y = @offset_y.clamp(0, [rows.length - 1, 0].max)
      @offset_y = 0 if rows.empty?
      @offset_x = @offset_x.clamp(0, max_x)
    end

    def on_key(event)
      case event.key
      when :up        then @offset_y = [@offset_y - 1, 0].max
      when :down      then @offset_y = [@offset_y + 1, max_offset_y_estimate].min
      when :page_up   then @offset_y = [@offset_y - 10, 0].max
      when :page_down then @offset_y = [@offset_y + 10, max_offset_y_estimate].min
      when :home      then @offset_y = 0
      when :end       then @offset_y = max_offset_y_estimate
      when :left      then @offset_x = [@offset_x - 1, 0].max
      when :right     then @offset_x = [@offset_x + 1, max_x].min
      else                 emit event
      end
    end

    def on_mouse(event)
      case event.button
      when :wheel_up   then @offset_y = [@offset_y - WHEEL_STEP, 0].max
      when :wheel_down then @offset_y = [@offset_y + WHEEL_STEP, max_offset_y_estimate].min
      else                  emit event
      end
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bg)

      # Per-canvas vertical clamp: don't scroll past the last page.
      max_offset = [rows.length - canvas.height, 0].max
      @offset_y = max_offset if @offset_y > max_offset

      canvas.height.times do |row_idx|
        file_row = @offset_y + row_idx
        text     = rows[file_row]
        break if text.nil?

        sliced = slice_by_columns(str: text, start_col: @offset_x, max_cols: canvas.width)
        canvas.row(row_idx).text(content: sliced, fg: theme.fg)
      end

      draw_indicators(canvas: canvas, theme: theme)
    end

    private

    def max_offset_y_estimate
      [rows.length - 1, 0].max
    end

    def max_x
      return 0 if rows.empty?

      widest = rows.map(&:display_width).max
      [widest - 1, 0].max
    end

    # Skip `start_col` display columns of input, then collect up to `max_cols`
    # columns of output. Wide chars (display_width == 2) that straddle either
    # edge are dropped to keep alignment honest.
    def slice_by_columns(str:, start_col:, max_cols:)
      return "" if str.nil? || str.empty?

      result = +""
      col    = 0
      str.each_char do |ch|
        w = ch.display_width
        if col >= start_col
          break if (col - start_col) + w > max_cols

          result << ch
        end
        col += w
      end
      result
    end

    def draw_indicators(canvas:, theme:)
      return if canvas.width.zero? || canvas.height.zero?

      canvas.text(content: "▲", x: canvas.width - 1, y: 0, fg: theme.dim) if @offset_y.positive?

      bottom_visible_row = @offset_y + canvas.height
      return unless bottom_visible_row < rows.length

      canvas.text(content: "▼", x: canvas.width - 1, y: canvas.height - 1, fg: theme.dim)
    end
  end
end
