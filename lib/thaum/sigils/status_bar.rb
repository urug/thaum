# frozen_string_literal: true

module Thaum
  # Horizontal bar of labeled segments separated by a configurable
  # delimiter. Segments are either plain Strings (decorative) or Hashes
  # `{ label:, on_click: }` whose click handler fires when the user
  # left-presses inside the segment's column range. Non-focusable —
  # status bars sit at the bottom of the focus order. Mouse events the
  # bar does not act on are eaten (not propagated) so the bar acts as
  # the floor of the click target.
  class StatusBar
    include Sigil

    DEFAULT_SEPARATOR = " │ "

    attr_reader :separator, :segments

    def initialize(segments:, separator: DEFAULT_SEPARATOR)
      @segments  = segments
      @separator = separator
      @ranges    = [] # parallel array: [start_col, end_col_exclusive] per segment
    end

    def focusable? = false

    def segments=(value)
      @segments = value
      request_render
    end

    def on_mouse(event)
      return unless event.action == :press && event.button == :left

      seg = segment_at(event.x) or return
      handler = on_click(seg) or return
      if handler.arity.zero?
        handler.call
      else
        handler.call(event)
      end
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bar_bg)
      @ranges = []
      x = 0
      width = canvas.width
      @segments.each_with_index do |seg, idx|
        x += draw_separator(canvas: canvas, theme: theme, x: x, width: width) if idx.positive?
        break if x >= width

        label = label(seg)
        label_w = label.display_width
        start = x
        canvas.text(content: label, x: x, fg: theme.fg, bg: theme.bar_bg)
        x += label_w
        finish = [x, width].min
        @ranges << [start, finish]
      end
    end

    private

    def draw_separator(canvas:, theme:, x:, width:)
      return 0 if x >= width

      canvas.text(content: @separator, x: x, fg: theme.dim, bg: theme.bar_bg)
      @separator.display_width
    end

    def label(seg)
      seg.is_a?(Hash) ? seg.fetch(:label).to_s : seg.to_s
    end

    def on_click(seg)
      return nil unless seg.is_a?(Hash)

      seg[:on_click]
    end

    def segment_at(col)
      @segments.each_with_index do |seg, idx|
        range = @ranges[idx] or next
        return seg if col >= range[0] && col < range[1]
      end
      nil
    end
  end
end
