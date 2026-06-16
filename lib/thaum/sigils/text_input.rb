# frozen_string_literal: true

module Thaum
  class TextInput
    include Sigil

    SubmittedEvent = Thaum::Event.define(:value)

    attr_reader :value, :cursor

    def initialize(value: "")
      @value  = value.dup
      @cursor = @value.length
    end

    def clear
      @value  = +""
      @cursor = 0
    end

    def on_key(event)
      key = event.key
      case key
      when String        then insert(key) unless event.ctrl? || event.alt?
      when :backspace    then backspace
      when :delete       then delete_forward
      when :left         then @cursor = [@cursor - 1, 0].max
      when :right        then @cursor = [@cursor + 1, @value.length].min
      when :home         then @cursor = 0
      when :end          then @cursor = @value.length
      when :enter        then emit SubmittedEvent.new(value: @value)
      else                    emit event
      end
    end

    def render(canvas:, theme:)
      offset    = scroll_offset(canvas.width)
      visible   = @value[offset..] || ""
      cursor_x  = display_width(@value[offset...@cursor])
      canvas.fill(bg: theme.input_bg)
      canvas.text(content: visible, fg: theme.fg, bg: theme.input_bg)
      canvas.cursor(x: cursor_x, y: 0) if focused?
    end

    private

    def insert(char)
      @value = @value[0...@cursor] + char + @value[@cursor..]
      @cursor += char.length
    end

    def backspace
      return if @cursor.zero?

      @value = @value[0...(@cursor - 1)] + @value[@cursor..]
      @cursor -= 1
    end

    def delete_forward
      return if @cursor >= @value.length

      @value = @value[0...@cursor] + @value[(@cursor + 1)..]
    end

    # Keep the cursor inside the visible window, measured in display columns
    # (not character indices) so wide chars (CJK, emoji) scroll correctly.
    # When the prefix fits, no scroll. Otherwise drop leading chars until the
    # cursor sits at column width-1.
    def scroll_offset(width)
      prefix_cols = display_width(@value[0...@cursor])
      return 0 if prefix_cols < width

      target = width - 1
      chars  = @value.chars
      offset = 0
      cols   = prefix_cols
      while cols > target && offset < @cursor
        cols -= chars[offset].display_width
        offset += 1
      end
      offset
    end

    def display_width(str) = (str || "").display_width
  end
end
