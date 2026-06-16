# frozen_string_literal: true

module Thaum
  # Tri-state boolean: unchecked, checked, indeterminate. Space (or Enter)
  # toggles between unchecked and checked; indeterminate is set
  # programmatically and any user toggle clears it. Emits Checkbox::ChangedEvent
  # with the new :checked value.
  class Checkbox
    include Sigil

    ChangedEvent = Thaum::Event.define(:checked)

    attr_reader :checked, :indeterminate
    attr_accessor :label

    def initialize(checked: false, indeterminate: false, label: nil)
      @checked       = checked
      @indeterminate = indeterminate
      @label         = label
    end

    def checked?       = @checked
    def indeterminate? = @indeterminate

    def indeterminate=(value)
      @indeterminate = value
      @checked = false if value
    end

    def on_key(event)
      case event.key
      when " ", :enter then toggle
      else emit(event)
      end
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bg)
      fg = focused? ? theme.accent : theme.fg
      canvas.text(content: "#{mark} #{@label}".rstrip, fg: fg, bg: theme.bg)
    end

    private

    def toggle
      @indeterminate = false
      @checked = !checked?
      emit ChangedEvent.new(checked: checked?)
    end

    def mark
      return "[-]" if indeterminate?

      checked? ? "[X]" : "[ ]"
    end
  end
end
