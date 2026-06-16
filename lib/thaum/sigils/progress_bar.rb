# frozen_string_literal: true

module Thaum
  # Horizontal progress bar. Two modes:
  # - determinate (default): `value` is 0.0..1.0, fills proportionally.
  # - indeterminate: a fixed-width block walks across the bar on each tick.
  # Non-focusable.
  class ProgressBar
    include Sigil

    INDETERMINATE_BLOCK_WIDTH = 6
    INDETERMINATE_INTERVAL    = 0.1

    attr_accessor :value
    attr_reader   :indeterminate

    def initialize(value: 0.0, indeterminate: false)
      @value         = value
      @indeterminate = indeterminate
      @offset        = 0
      @elapsed       = 0.0
    end

    def focusable? = false
    def indeterminate? = @indeterminate

    def on_tick(event)
      return unless indeterminate?

      @elapsed += event.delta
      advanced = false
      while @elapsed >= INDETERMINATE_INTERVAL
        @elapsed -= INDETERMINATE_INTERVAL
        @offset += 1
        advanced = true
      end
      request_render if advanced
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bg)
      if indeterminate?
        render_indeterminate(canvas: canvas,
                             theme: theme)
      else
        render_determinate(canvas: canvas, theme: theme)
      end
    end

    private

    def render_determinate(canvas:, theme:)
      filled = (@value.clamp(0.0, 1.0) * canvas.width).round
      canvas.fill(bg: theme.accent, width: filled) if filled.positive?
    end

    def render_indeterminate(canvas:, theme:)
      span  = canvas.width + INDETERMINATE_BLOCK_WIDTH
      start = (@offset % span) - INDETERMINATE_BLOCK_WIDTH
      x     = [start, 0].max
      w     = [INDETERMINATE_BLOCK_WIDTH - (x - start), canvas.width - x].min
      canvas.fill(bg: theme.accent, x: x, width: w) if w.positive?
    end
  end
end
