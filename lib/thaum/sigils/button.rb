# frozen_string_literal: true

module Thaum
  class Button
    include Sigil

    PressedEvent = Thaum::Event.define(:label)

    attr_reader :label

    def initialize(label:, disabled: false)
      @label    = label
      @disabled = disabled
    end

    def disabled?  = @disabled
    def focusable? = !@disabled

    def on_key(event)
      case event.key
      when :enter, " " then activate
      else                  emit event
      end
    end

    def render(canvas:, theme:)
      fg, bg = colors(theme)
      canvas.fill(bg: bg) if bg
      canvas.text(content: @label, fg: fg, bg: bg, align: :center)
    end

    private

    def colors(theme)
      return [theme.dim, nil] if disabled?
      return [theme.accent, theme.pressed] if focused?

      [theme.fg, nil]
    end

    def activate
      return if disabled?

      emit PressedEvent.new(label: @label)
    end
  end
end
