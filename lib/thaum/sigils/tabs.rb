# frozen_string_literal: true

module Thaum
  # Horizontal tab strip. ←/→ cycle the active tab (with wrap). Emits
  # Tabs::ActivatedEvent when the active index changes. The content under each
  # tab is the App's concern — Tabs only owns the strip.
  class Tabs
    include Sigil

    ActivatedEvent = Thaum::Event.define(:index, :label)

    attr_reader :labels, :active

    def initialize(labels:, active: 0)
      raise ArgumentError, "Tabs needs at least one label" if labels.empty?

      @labels = labels
      @active = active.clamp(0, labels.length - 1)
    end

    def current = @labels[@active]

    def on_key(event)
      case event.key
      when :left  then move(-1)
      when :right then move(1)
      else             emit event
      end
    end

    def render(canvas:, theme:)
      canvas.fill(bg: theme.bar_bg)
      x = 0
      @labels.each_with_index do |label, idx|
        x += draw_tab(canvas: canvas, label: label, idx: idx, x: x, theme: theme)
      end
    end

    private

    def move(delta)
      new_idx = (@active + delta) % @labels.length
      return if new_idx == @active

      @active = new_idx
      emit ActivatedEvent.new(index: @active, label: current)
    end

    def draw_tab(canvas:, label:, idx:, x:, theme:)
      cell  = " #{label} "
      width = cell.display_width
      bg    = idx == @active ? theme.selection : theme.bar_bg
      fg    = idx == @active ? theme.selection_fg : theme.fg
      canvas.fill(bg: bg, x: x, width: width)
      canvas.text(content: cell, x: x, fg: fg, bg: bg)
      width
    end
  end
end
