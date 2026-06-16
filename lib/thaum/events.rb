# frozen_string_literal: true

# Framework-internal event types pushed onto the main queue by the input
# reader, signal traps, and the tick timer. KeyEvent has its own file
# because it carries modifier predicates.
module Thaum
  PasteEvent  = Event.define(:text)
  ResizeEvent = Event.define(:width, :height)
  TickEvent   = Event.define(:time, :delta)

  # SGR mouse event. Actions: :press / :release / :drag / :scroll.
  # Scroll direction is folded into `button` (:wheel_up / :wheel_down).
  # Modifier booleans (shift/alt/ctrl) come from the SGR Cb bits.
  #
  # `x`/`y` are canvas-relative to the receiving Sigil and are set by the
  # dispatcher right before invoking on_mouse. `abs_x`/`abs_y` are the
  # terminal-absolute coordinates and are always populated.
  MouseEvent = Event.define(:button, :action, :x, :y, :abs_x, :abs_y, :shift, :alt, :ctrl) do
    def initialize(button:, action:, abs_x:, abs_y:, x: abs_x, y: abs_y,
                   shift: false, alt: false, ctrl: false)
      super
    end

    def shift? = shift
    def alt?   = alt
    def ctrl?  = ctrl
  end
end
