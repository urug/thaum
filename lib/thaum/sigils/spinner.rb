# frozen_string_literal: true

module Thaum
  # Animated activity indicator. Advances one frame per `interval` seconds,
  # driven by tick deltas (not wall clock — works with whatever tick rate
  # the app runs at). Non-focusable.
  class Spinner
    include Sigil

    DEFAULT_FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze

    attr_reader :frame, :frames, :interval

    def initialize(frames: DEFAULT_FRAMES, interval: 0.1)
      @frames    = frames
      @interval  = interval
      @frame     = 0
      @elapsed   = 0.0
    end

    def focusable? = false

    def on_tick(event)
      @elapsed += event.delta
      advanced = false
      while @elapsed >= @interval
        @elapsed -= @interval
        @frame = (@frame + 1) % @frames.length
        advanced = true
      end
      request_render if advanced
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bg)
      canvas.text(content: @frames[@frame], fg: theme.accent, bg: theme.bg)
    end
  end
end
