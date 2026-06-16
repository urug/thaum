# frozen_string_literal: true

module Thaum
  class Select
    include Sigil

    SelectedEvent = Thaum::Event.define(:index, :item)

    attr_reader :items, :cursor

    def initialize(items:, cursor: 0)
      @items  = items
      @cursor = cursor
    end

    def current = items[cursor]

    def on_key(event)
      case event.key
      when :down  then @cursor = [cursor + 1, items.length - 1].min if items.any?
      when :up    then @cursor = [cursor - 1, 0].max
      when :enter then emit_selected
      else emit(event)
      end
    end

    def render(canvas:, theme:)
      offset = scroll_offset(canvas.height)
      visible_range = offset...(offset + canvas.height)

      visible_range.each_with_index do |item_idx, row_idx|
        item = items[item_idx] or next
        row  = canvas.row(row_idx) or break

        bg = item_idx == cursor ? theme.selection : theme.bg
        fg = item_idx == cursor ? theme.selection_fg : theme.fg
        row.fill(bg: bg)
        row.text(content: item.to_s, fg: fg, bg: bg)
      end
    end

    private

    def emit_selected
      return if items.empty?

      emit SelectedEvent.new(index: cursor, item: items[cursor])
    end

    def scroll_offset(height)
      return 0 if cursor < height

      cursor - height + 1
    end
  end
end
