# frozen_string_literal: true

# Dev log console — the viewer half.
#
# Usage:
#   1. In one terminal:   bundle exec ruby examples/log_reader.rb thaum.log
#   2. In another:        bundle exec ruby examples/log_generator.rb thaum.log
#
# Watch the generator's log lines appear live here. Start either side first,
# in any order — the file is the only coupling.
#
# Keys:  ↑/↓ PgUp/PgDn  scroll (drops follow)   End  jump to bottom (follow)
#        f  cycle minimum level   /  search   esc  clear search / quit

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

# Tails a Thaum log file: reads new bytes on each tick, parses complete lines
# into level-tagged rows, follows the tail, filters by level and substring.
# Bespoke (not ScrollView) because per-line color, follow-tail, and filtering
# are all log-viewer-specific. Its parsing/state logic is unit-tested in
# test/log/test_log_view.rb.
class LogView
  include Thaum::Sigil

  Row = Data.define(:level, :text)

  LEVELS  = %i[debug info warn error].freeze
  LINE_RE = /\A\d\d:\d\d:\d\d\.\d\d\d (\w+)\s{2}(.*)\z/m

  attr_reader :rows, :min_level, :query

  def initialize(path:)
    @path       = path
    @offset     = 0           # bytes consumed so far
    @partial    = +""         # trailing line not yet terminated by "\n"
    @rows       = []
    @last_level = :info       # level inherited by continuation (backtrace) lines
    @follow     = true
    @scroll     = 0           # top row index when not following
    @min_level  = :debug
    @query      = nil
  end

  def follow? = @follow

  def min_level=(level)
    @min_level = level
    request_render
  end

  def cycle_min_level
    @min_level = LEVELS[(LEVELS.index(@min_level) + 1) % LEVELS.size]
    request_render
  end

  def query=(string)
    @query = string.nil? || string.empty? ? nil : string
    request_render
  end

  # Rows passing the level floor and the search substring.
  def visible_rows
    floor = LEVELS.index(@min_level)
    @rows.select do |row|
      LEVELS.index(row.level) >= floor && (@query.nil? || row.text.include?(@query))
    end
  end

  # --- tailing ---

  def poll
    return unless File.exist?(@path)

    reset! if File.size(@path) < @offset # target restarted (truncate-on-open shrank it)
    data = read_new_bytes
    return if data.empty?

    ingest(data)
    request_render
  end

  def on_tick(_event) = poll

  # --- scrolling ---

  def scroll_up   = scroll_by(-1)
  def scroll_down = scroll_by(1)
  def page_up     = scroll_by(-10)
  def page_down   = scroll_by(10)

  def scroll_to_end
    @follow = true
    request_render
  end

  def scroll_to_top
    @follow = false
    @scroll = 0
    request_render
  end

  def on_key(event)
    case event.key
    when :up        then scroll_up
    when :down      then scroll_down
    when :page_up   then page_up
    when :page_down then page_down
    when :home      then scroll_to_top
    when :end       then scroll_to_end
    else emit(event) # let the app handle f / / / esc
    end
  end

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    rows   = visible_rows
    height = canvas.height
    max    = [rows.size - height, 0].max
    top    = @follow ? max : @scroll.clamp(0, max)

    rows[top, height].to_a.each_with_index do |row, i|
      canvas.text(content: row.text, y: i, fg: color_for(row.level, theme))
    end
  end

  private

  def color_for(level, theme)
    case level
    when :debug then theme.dim
    when :warn  then theme.warning_fg
    when :error then theme.error_fg
    else theme.fg
    end
  end

  def reset!
    @offset     = 0
    @partial    = +""
    @rows       = []
    @last_level = :info
  end

  def read_new_bytes
    File.open(@path, "rb") do |io|
      io.seek(@offset)
      data = io.read || ""
      @offset = io.pos
      data
    end
  end

  def ingest(data)
    buffer  = @partial + data
    parts   = buffer.split("\n", -1)
    @partial = parts.pop || +"" # last element is the unterminated remainder
    parts.each { |line| @rows << parse_line(line) }
  end

  def parse_line(line)
    if (match = LINE_RE.match(line))
      level = match[1].downcase.to_sym
      level = :info unless LEVELS.include?(level)
      @last_level = level
      Row.new(level: level, text: line)
    else
      Row.new(level: @last_level, text: line) # continuation (e.g. a backtrace frame)
    end
  end

  def scroll_by(delta)
    @follow = false
    @scroll = [@scroll + delta, 0].max
    request_render
  end
end

# The viewer app: LogView fills the screen; a one-line search field sits above
# a status bar. "/" focuses search; esc clears it (or quits when not searching).
class LogReaderApp
  include Thaum::App

  def initialize(path)
    @path      = path
    @view      = LogView.new(path: path)
    @search    = Thaum::TextInput.new
    @searching = false
    @bar       = Thaum::StatusBar.new(segments: status_segments)
  end

  def theme = Thaum::Themes::CATPPUCCIN_MOCHA

  def initial_focus = @view

  def on_mount
    @view.poll
  end

  def on_tick(_event)
    @view.query = @search.value if @searching
    @bar.segments = status_segments
  end

  def on_key(event)
    case event.key
    when "/" then start_search
    when "f" then @view.cycle_min_level
    when :escape then @searching ? stop_search : quit
    end
  end

  # TextInput bubbles Submitted on Enter — accept the query and leave the field.
  def on_event(event)
    stop_search if event.is_a?(Thaum::TextInput::SubmittedEvent)
  end

  def partition
    vertical do
      region(height: :fill) { @view }
      region(height: 1)     { @search }
      region(height: 1)     { @bar }
    end
  end

  private

  def start_search
    @searching = true
    focus(@search)
    request_render
  end

  def stop_search
    @searching = false
    @search.clear
    @view.query = nil
    focus(@view)
    request_render
  end

  def status_segments
    [
      File.basename(@path),
      "#{@view.visible_rows.size} lines",
      "min: #{@view.min_level}",
      @view.follow? ? "follow" : "scroll",
      "[/] search  [f] level  [esc] quit"
    ]
  end
end

if __FILE__ == $PROGRAM_NAME
  path = ARGV[0] || "thaum.log"
  File.write(path, "") unless File.exist?(path) # so the reader has something to tail
  Thaum.run(LogReaderApp.new(path))
end
