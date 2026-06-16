# frozen_string_literal: true

# Usage: bundle exec ruby examples/theme_picker.rb
#
# The App's theme is whatever the list cursor is on. Thaum resolves
# app.theme fresh each frame, so a cursor move reflects instantly in
# the preview pane — no events, no context, no on_update.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

SLOTS = %i[
  bg fg accent border
  success_fg warning_fg error_fg info_fg
  dim muted_fg disabled_fg
  selection selection_fg pressed
  input_bg bar_bg
].freeze

class ThemeList
  include Thaum::Sigil

  def initialize
    @themes = Thaum::Themes.names
    @cursor = 0
  end

  def current = @themes.fetch(@cursor)

  def on_key(event)
    case event.key
    when :up then move(-1)
    when :down then move(1)
    else emit(event)
    end
  end

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    @themes.each_with_index do |item, i|
      row = canvas.row(i) or break

      selected = i == @cursor
      bg = selected ? theme.selection : theme.bar_bg
      fg = selected ? theme.accent    : theme.fg
      row.fill(bg: bg)
      row.text(content: " #{item}", fg: fg, bg: bg)
    end
  end

  def move(offset)
    @cursor = (@cursor + offset) % @themes.size
  end
end

class PreviewSigil
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    SLOTS.each_with_index do |slot, i|
      row = canvas.row(i + 1) or break

      hex = theme.send(slot)
      row.fill(bg: hex, x: 2, width: 6)
      row.text(content: "#{slot.to_s.ljust(14)} #{hex}", fg: theme.fg, x: 10)
    end
  end
end

class ThemePickerApp
  include Thaum::App

  def initialize
    @list    = ThemeList.new
    @preview = PreviewSigil.new
  end

  def theme = Thaum::Themes[@list.current]

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    horizontal do
      region(width: 22) { @list }
      region(width: :fill) { @preview }
    end
  end
end

Thaum.run(ThemePickerApp.new)
