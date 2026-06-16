# frozen_string_literal: true

# Usage: bundle exec ruby examples/picker.rb
#
# Filter-as-you-type list selector. The TextInput on top filters the
# list below as you type. Arrow keys navigate the filtered results
# (focus stays on the input — :up/:down bubble out of TextInput, so the
# App routes them to the list). Enter picks the highlighted item and
# quits, printing the selection.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

LANGUAGES = %w[
  Ruby Python Elixir Erlang Haskell OCaml Rust Go Crystal Zig
  JavaScript TypeScript CoffeeScript Lua Perl Raku Tcl
  C C++ Java Kotlin Scala Clojure Groovy
  Swift Dart Nim D Julia
  Lisp Scheme Racket Prolog SmallTalk Forth
].freeze

class FilteredList
  include Thaum::Sigil

  PickedEvent = Thaum::Event.define(:value)

  def initialize(source:, query_source:)
    @source       = source
    @query_source = query_source
    @cursor       = 0
    @cached_query = nil
    @cached_items = source
  end

  def focusable? = false

  def current = items[@cursor]

  def items
    q = @query_source.value
    return @cached_items if q == @cached_query

    @cached_query = q
    @cached_items = q.empty? ? @source : @source.select { |s| s.downcase.include?(q.downcase) }
    @cursor = @cursor.clamp(0, [@cached_items.length - 1, 0].max)
    @cached_items
  end

  def cursor_up
    @cursor = [@cursor - 1, 0].max
  end

  def cursor_down
    last = [items.length - 1, 0].max
    @cursor = (@cursor + 1).clamp(0, last)
  end

  def pick
    return if items.empty?

    emit PickedEvent.new(value: current)
  end

  def render(canvas:, theme:)
    list   = items
    offset = scroll_offset(height: canvas.height, count: list.length)
    canvas.fill(bg: theme.bg)
    visible = list[offset, canvas.height] || []
    visible.each_with_index do |item, row_idx|
      draw_row(canvas: canvas, item: item, item_idx: offset + row_idx, row_idx: row_idx, theme: theme)
    end
  end

  private

  def draw_row(canvas:, item:, item_idx:, row_idx:, theme:)
    row = canvas.row(row_idx) or return

    sel = item_idx == @cursor
    bg  = sel ? theme.selection    : theme.bg
    fg  = sel ? theme.selection_fg : theme.fg
    row.fill(bg: bg)
    row.text(content: " #{item}", fg: fg, bg: bg)
  end

  def scroll_offset(height:, count:)
    return 0 if @cursor < height || count <= height

    [@cursor - height + 1, count - height].min
  end
end

class HintBar
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " type to filter   ↑/↓ navigate   enter picks   esc quits", fg: theme.dim)
  end
end

class PickerApp
  include Thaum::App

  def initialize
    @input = Thaum::TextInput.new
    @list  = FilteredList.new(source: LANGUAGES, query_source: @input)
    @hint  = HintBar.new
    @picked = nil
  end

  def theme  = Thaum::Themes::CATPPUCCIN_MOCHA
  def result = @picked

  def on_mount
    focus(@input)
  end

  def on_key(event)
    case event.key
    when :up     then @list.cursor_up
    when :down   then @list.cursor_down
    when :escape then quit
    end
  end

  def on_event(event)
    case event
    when Thaum::TextInput::SubmittedEvent
      @list.pick
    when FilteredList::PickedEvent
      @picked = event.value
      quit
    end
  end

  def partition
    vertical do
      region(height: 1)     { @input }
      region(height: :fill) { @list }
      region(height: 1)     { @hint }
    end
  end
end

app = PickerApp.new
Thaum.run(app)
puts app.result if app.result
