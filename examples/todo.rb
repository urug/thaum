# frozen_string_literal: true

# Usage: bundle exec ruby examples/todo.rb
#
# Centered todo card on the Gruvbox Dark theme.
# - type into the input + Enter to add (input clears)
# - ↑/↓ moves between the input and the list items
# - space toggles [ ] / [X]
# - delete removes the focused item
# - Tab switches between the input and the Quit button

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

TodoItem = Data.define(:text, :done) do
  def initialize(text:, done: false)
    super
  end

  def toggle = with(done: !done)
end

class TodoList
  include Thaum::Sigil

  attr_reader :cursor, :items

  def initialize
    @items  = []
    @cursor = 0
  end

  def add(text)
    @items << TodoItem.new(text: text)
  end

  def reset_cursor
    @cursor = 0
  end

  def on_key(event)
    case event.key
    when :up                  then move_up_or_bubble(event)
    when :down                then @cursor = (@cursor + 1).clamp(0, [@items.size - 1, 0].max)
    when " "                  then toggle
    when :delete, :backspace  then delete_item
    else emit(event)
    end
  end

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    inner = canvas.border(fg: theme.border, style: :rounded)
    @items.each_with_index do |item, i|
      row = inner.row(i) or break

      render_item(row, item, focused: focused? && i == @cursor, theme: theme)
    end
  end

  private

  def move_up_or_bubble(event)
    if @cursor.positive?
      @cursor -= 1
    else
      emit(event) # bubble :up so the App can move focus back to the input
    end
  end

  def render_item(row, item, focused:, theme:)
    bg   = focused ? theme.selection : theme.bg
    fg   = item_fg(item, focused: focused, theme: theme)
    mark = item.done ? "[X]" : "[ ]"
    row.fill(bg: bg)
    row.text(content: " #{mark} #{item.text}", fg: fg, bg: bg)
  end

  def item_fg(item, focused:, theme:)
    return theme.success_fg if item.done

    focused ? theme.accent : theme.fg
  end

  def toggle
    return if @items.empty?

    @items[@cursor] = @items[@cursor].toggle
  end

  def delete_item
    return if @items.empty?

    @items.delete_at(@cursor)
    @cursor = @cursor.clamp(0, [@items.size - 1, 0].max)
  end
end

# Local button that fills its own bg so the card surface stays uniform.
class ActionButton
  include Thaum::Sigil

  def initialize(label:)
    @label = label
  end

  def on_key(event)
    case event.key
    when :enter, " " then emit(Thaum::Button::PressedEvent.new(label: @label))
    else emit(event)
    end
  end

  def render(canvas:, theme:)
    bg = focused? ? theme.selection : theme.bg
    fg = focused? ? theme.accent    : theme.fg
    canvas.fill(bg: bg)
    canvas.text(content: @label, fg: fg, bg: bg, align: :center)
  end
end

class Help
  include Thaum::Sigil

  LINES = [
    "↑/↓ navigate   space toggles   delete removes",
    "tab to Quit   enter adds item   esc quits"
  ].freeze

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    LINES.each_with_index do |line, i|
      row = canvas.row(i) or break
      row.text(content: "  #{line}", fg: theme.info_fg)
    end
  end
end

class Surface
  include Thaum::Sigil

  def initialize(slot)
    @slot = slot
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.send(@slot))
  end
end

class TodoApp
  include Thaum::App

  CARD_WIDTH  = 52
  CARD_HEIGHT = 18

  def initialize
    @input = Thaum::TextInput.new
    @list  = TodoList.new
    @quit  = ActionButton.new(label: "Quit")
    @help  = Help.new
    @pad_l = Surface.new(:bar_bg)
    @pad_r = Surface.new(:bar_bg)
    @pad_t = Surface.new(:bar_bg)
    @pad_b = Surface.new(:bar_bg)
  end

  def theme = Thaum::Themes::GRUVBOX_DARK

  def on_event(event)
    case event
    when Thaum::TextInput::SubmittedEvent then submit(event.value)
    when Thaum::Button::PressedEvent      then press(event.label)
    end
  end

  def on_key(event)
    case event.key
    when :escape        then quit
    when :tab, :backtab then toggle_tab_focus
    when :down          then down_pressed
    when :up            then up_pressed
    end
  end

  def partition
    horizontal do
      region(width: :fill)      { @pad_l }
      region(width: CARD_WIDTH) { column }
      region(width: :fill)      { @pad_r }
    end
  end

  private

  def column
    vertical do
      region(height: :fill)       { @pad_t }
      region(height: CARD_HEIGHT) { card }
      region(height: :fill)       { @pad_b }
    end
  end

  def card
    vertical do
      region(height: 1)     { @input }
      region(height: :fill) { @list }
      region(height: 1)     { @quit }
      region(height: 2)     { @help }
    end
  end

  def toggle_tab_focus
    focus(focused_sigil.equal?(@input) ? @quit : @input)
  end

  def down_pressed
    focus(@list) if focused_sigil.equal?(@input) && @list.items.any?
  end

  def up_pressed
    focus(@input) if focused_sigil.equal?(@list)
  end

  def submit(value)
    value = value.strip
    return if value.empty?

    @list.add(value)
    @input.clear
  end

  def press(label)
    quit if label == "Quit"
  end
end

TodoApp.run
