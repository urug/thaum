# frozen_string_literal: true

# Usage: bundle exec ruby examples/octagram_picker.rb
#
# Demonstrates Thaum::Octagram by packaging a filter-as-you-type picker
# (TextInput + filtered list) as a single distributable component.
#
# The Picker Octagram:
# - declares its own partition (TextInput on top, filtered list below)
# - draws a rounded border behind its children (the Octagram render hook)
# - intercepts events bubbling up from its children:
#     :up/:down → forward to the internal list (App never sees them)
#     :escape   → emit Picker::CancelledEvent
#     SubmittedEvent → translate to Picker::SelectedEvent(value:)
#
# Compare with examples/picker.rb (same UX, but the App had to know
# about the filter list and route :up/:down itself). With Octagram, the
# App only knows about Picker::SelectedEvent and Picker::CancelledEvent.

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

  def initialize(source:, query_source:)
    @source       = source
    @query_source = query_source
    @cursor       = 0
    @cached_query = nil
    @cached_items = source
  end

  def focusable? = false

  def items
    q = @query_source.value
    return @cached_items if q == @cached_query

    @cached_query = q
    @cached_items = q.empty? ? @source : @source.select { |s| s.downcase.include?(q.downcase) }
    @cursor = @cursor.clamp(0, [@cached_items.length - 1, 0].max)
    @cached_items
  end

  def current   = items[@cursor]
  def cursor_up = (@cursor = [@cursor - 1, 0].max)

  def cursor_down
    last = [items.length - 1, 0].max
    @cursor = (@cursor + 1).clamp(0, last)
  end

  def render(canvas:, theme:)
    list = items
    canvas.fill(bg: theme.bg)
    list.each_with_index do |item, i|
      break if i >= canvas.height

      draw_row(canvas: canvas, item: item, i: i, theme: theme)
    end
  end

  private

  def draw_row(canvas:, item:, i:, theme:)
    row = canvas.row(i) or return

    sel = i == @cursor
    bg  = sel ? theme.selection    : theme.bg
    fg  = sel ? theme.selection_fg : theme.fg
    row.fill(bg: bg)
    row.text(content: " #{item}", fg: fg, bg: bg)
  end
end

class Picker
  include Thaum::Octagram

  SelectedEvent  = Thaum::Event.define(:value)
  CancelledEvent = Thaum::Event.define

  attr_reader :input, :list

  def initialize(items:)
    @input = Thaum::TextInput.new
    @list  = FilteredList.new(source: items, query_source: @input)
  end

  def partition
    vertical do
      region(height: 1)     { @input }
      region(height: :fill) { @list }
    end
  end

  # Reserve a 1-cell ring around the children so the rounded border
  # the render hook draws underneath survives.
  def partition_inset = { top: 1, bottom: 1, left: 1, right: 1 }

  def render(canvas:, theme:)
    canvas.border(fg: theme.border, style: :rounded)
  end

  def on_key(event)
    case event.key
    when :up     then @list.cursor_up
    when :down   then @list.cursor_down
    when :escape then emit CancelledEvent.new
    else              emit event
    end
  end

  def on_event(event)
    case event
    when Thaum::TextInput::SubmittedEvent
      value = @list.current
      emit(value ? SelectedEvent.new(value: value) : event)
    else
      emit event
    end
  end
end

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " type to filter   ↑/↓ navigate   enter picks   esc cancels", fg: theme.dim)
  end
end

# Sits next to the Picker. Belongs to the App, not the Octagram —
# visible proof that the App composes the Picker alongside other
# sigils it owns. Updates when the user navigates inside the Picker,
# polling the Picker's exposed list state at render time.
class Notes
  include Thaum::Sigil

  def initialize(picker:)
    @picker = picker
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    inner = canvas.border(fg: theme.dim, style: :single)
    draw_header(canvas: inner, theme: theme)
    draw_state(canvas: inner, theme: theme)
  end

  private

  def draw_header(canvas:, theme:)
    canvas.text(content: "App-owned sigil",   y: 0, fg: theme.accent)
    canvas.text(content: "(not inside the",   y: 1, fg: theme.dim)
    canvas.text(content: " Picker Octagram)", y: 2, fg: theme.dim)
  end

  def draw_state(canvas:, theme:)
    cursor  = @picker.list.current || "—"
    matches = @picker.list.items.length
    canvas.text(content: "Query:    #{@picker.input.value.inspect}", y: 4, fg: theme.fg)
    canvas.text(content: "Matches:  #{matches}",                     y: 5, fg: theme.fg)
    canvas.text(content: "Cursor:   #{cursor}",                      y: 6, fg: theme.fg)
  end
end

class PickerApp
  include Thaum::App

  attr_reader :result

  def initialize
    @picker = Picker.new(items: LANGUAGES)
    @notes  = Notes.new(picker: @picker)
    @hint   = Hint.new
    @result = nil
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def on_mount
    focus(@picker.input)
  end

  def on_event(event)
    case event
    when Picker::SelectedEvent
      @result = event.value
      quit
    when Picker::CancelledEvent
      quit
    end
  end

  def partition
    vertical do
      region(height: :fill) do
        horizontal do
          region(width: 42)    { @picker }
          region(width: :fill) { @notes }
        end
      end
      region(height: 1) { @hint }
    end
  end
end

app = PickerApp.new
Thaum.run(app)
puts app.result if app.result
