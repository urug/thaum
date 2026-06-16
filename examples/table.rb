# frozen_string_literal: true

# Usage: bundle exec ruby examples/table.rb
#
# Demonstrates Thaum::Table. Auto-computed column widths, vertical
# scrolling, row selection. Enter prints the selected row after exit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

HEADERS = %w[Name Size Type Modified].freeze

ROWS = [
  ["CLAUDE.md",        "1.2K",  "doc",   "2026-05-27"],
  ["DECISIONS.md",     "8.4K",  "doc",   "2026-06-10"],
  ["Gemfile",          "237B",  "ruby",  "2026-05-27"],
  ["LICENSE.txt",      "1.1K",  "text",  "2026-05-27"],
  ["README.md",        "412B",  "doc",   "2026-05-27"],
  ["Rakefile",         "188B",  "ruby",  "2026-05-27"],
  ["bin/console",      "187B",  "ruby",  "2026-05-27"],
  ["bin/setup",        "133B",  "ruby",  "2026-05-27"],
  ["examples/counter.rb", "1.1K", "ruby", "2026-05-31"],
  ["examples/layout_demo.rb", "2.3K", "ruby", "2026-06-04"],
  ["examples/picker.rb",     "3.6K",  "ruby",  "2026-06-15"],
  ["examples/stopwatch.rb",  "1.9K",  "ruby",  "2026-06-02"],
  ["examples/theme_picker.rb", "2.0K", "ruby", "2026-06-10"],
  ["examples/todo.rb", "5.4K", "ruby", "2026-06-09"],
  ["lib/thaum.rb", "4.7K", "ruby", "2026-06-15"],
  ["lib/thaum/action.rb",    "1.4K",  "ruby",  "2026-06-04"],
  ["lib/thaum/app.rb",       "2.9K",  "ruby",  "2026-06-10"],
  ["lib/thaum/buffer.rb",    "1.6K",  "ruby",  "2026-06-02"],
  ["lib/thaum/canvas.rb",    "5.1K",  "ruby",  "2026-06-10"],
  ["lib/thaum/color.rb",     "3.3K",  "ruby",  "2026-06-08"],
  ["lib/thaum/escape_parser.rb", "4.2K", "ruby", "2026-06-02"],
  ["lib/thaum/events.rb",    "418B",  "ruby",  "2026-06-10"],
  ["lib/thaum/layout.rb",    "3.7K",  "ruby",  "2026-06-04"],
  ["lib/thaum/renderer.rb",  "4.5K",  "ruby",  "2026-06-08"],
  ["lib/thaum/sigil.rb",     "1.1K",  "ruby",  "2026-06-04"],
  ["lib/thaum/sigils/button.rb", "744B", "ruby", "2026-06-05"],
  ["lib/thaum/sigils/scroll_view.rb", "2.6K", "ruby", "2026-06-15"],
  ["lib/thaum/sigils/select.rb",    "1.1K",  "ruby", "2026-06-05"],
  ["lib/thaum/sigils/table.rb",     "3.9K",  "ruby", "2026-06-15"],
  ["lib/thaum/sigils/text.rb",      "316B",  "ruby", "2026-06-04"],
  ["lib/thaum/sigils/text_input.rb", "1.7K", "ruby", "2026-06-15"],
  ["lib/thaum/themes.rb", "2.8K", "ruby", "2026-06-10"]
].freeze

class Hint
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    canvas.text(content: " ↑/↓ navigate   pgup/pgdn jump   home/end edges   enter picks   esc quits",
                fg: theme.muted_fg)
  end
end

class FileTable
  include Thaum::Sigil

  PAGE_STEP = 10

  attr_reader :rows, :cursor, :offset

  def initialize(headers:, rows:)
    @headers = headers
    @rows    = rows
    @cursor  = 0
    @offset  = 0
  end

  SelectedEvent = Thaum::Event.define(:index, :row)

  def on_key(event)
    case event.key
    when :up        then @cursor = [@cursor - 1, 0].max
    when :down      then @cursor = [@cursor + 1, rows.length - 1].min if rows.any?
    when :home      then @cursor = 0
    when :end       then @cursor = rows.length - 1 if rows.any?
    when :page_up   then @cursor = [@cursor - PAGE_STEP, 0].max
    when :page_down then @cursor = [@cursor + PAGE_STEP, rows.length - 1].min if rows.any?
    when :enter     then emit_selected
    else                 emit event
    end
  end

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    visible_offset(canvas)

    render_header(canvas: canvas, theme: theme)
    render_separator(canvas: canvas, theme: theme)
    render_data_rows(canvas: canvas, theme: theme)
  end

  private

  def emit_selected
    return if rows.empty?

    emit SelectedEvent.new(index: @cursor, row: rows[@cursor])
  end

  def render_header(canvas:, theme:)
    row = canvas.row(0) or return

    row.fill(bg: theme.bar_bg)
    row.text(content: @headers.join(" | "), fg: theme.accent, bg: theme.bar_bg)
  end

  def render_separator(canvas:, theme:)
    row = canvas.row(1) or return

    row.fill(bg: theme.bg)
    row.text(content: "─" * canvas.width, fg: theme.border, bg: theme.bg)
  end

  def render_data_rows(canvas:, theme:, widths: nil)
    visible_rows = canvas.height - 2
    return if visible_rows <= 0

    visible_rows.times do |i|
      file_idx = @offset + i
      row_data = rows[file_idx] or break
      row      = canvas.row(i + 2) or break

      selected = file_idx == @cursor
      bg = selected ? theme.selection : theme.bg
      fg = color_for_type(row_data[2], selected: selected, theme: theme)
      row.fill(bg: bg)
      row.text(content: row_data.join(" | "), fg: fg, bg: bg)
    end
  end

  def visible_offset(canvas)
    visible_rows = canvas.height - 2
    return if visible_rows <= 0

    if @cursor < @offset
      @offset = @cursor
    elsif @cursor >= @offset + visible_rows
      @offset = @cursor - visible_rows + 1
    end
  end

  def color_for_type(file_type, selected:, theme:)
    return theme.selection_fg if selected

    case file_type
    when "ruby"  then theme.success_fg
    when "doc"   then theme.info_fg
    when "text"  then theme.muted_fg
    else              theme.fg
    end
  end
end

class TableApp
  include Thaum::App

  attr_reader :result

  def initialize
    @table  = FileTable.new(headers: HEADERS, rows: ROWS)
    @hint   = Hint.new
    @result = nil
  end

  def on_mount
    focus(@table)
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def on_event(event)
    return unless event.is_a?(FileTable::SelectedEvent)

    @result = event.row
    quit
  end

  def partition
    vertical do
      region(height: :fill) { @table }
      region(height: 1)     { @hint }
    end
  end
end

app = TableApp.new
Thaum.run(app)
puts app.result.join(" | ") if app.result
