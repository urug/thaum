# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require_relative "../../examples/log_reader"

# LogView lives inline in examples/log_reader.rb; its parsing/state logic is
# pure and tested here (the live run loop is not, per the design).
class TestLogView < Minitest::Test
  def setup
    @dir  = Dir.mktmpdir("thaum-logview")
    @path = File.join(@dir, "thaum.log")
    File.write(@path, "")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  def view = @view ||= LogView.new(path: @path)

  def append(*lines) = File.write(@path, lines.map { "#{_1}\n" }.join, mode: "a")

  # --- incremental parse ---

  def test_parses_complete_lines_into_levelled_rows
    append("12:00:00.000 INFO  mounted", "12:00:00.100 WARN  slow frame")
    view.poll

    assert_equal 2, view.rows.size
    assert_equal :info, view.rows[0].level
    assert_equal :warn, view.rows[1].level
    assert_includes view.rows[0].text, "mounted"
  end

  def test_only_new_lines_are_appended_on_subsequent_polls
    append("12:00:00.000 INFO  one")
    view.poll
    append("12:00:00.100 INFO  two")
    view.poll

    assert_equal 2, view.rows.size
    assert_includes view.rows[1].text, "two"
  end

  # --- partial-line buffering ---

  def test_partial_trailing_line_is_buffered_until_complete
    File.write(@path, "12:00:00.000 INFO  whole\n12:00:00.100 INFO  partial")
    view.poll
    assert_equal 1, view.rows.size # partial not yet emitted

    File.write(@path, "12:00:00.000 INFO  whole\n12:00:00.100 INFO  partial done\n")
    view.poll
    assert_equal 2, view.rows.size
    assert_includes view.rows[1].text, "partial done"
  end

  # --- continuation (backtrace) lines inherit the previous level ---

  def test_non_prefixed_line_inherits_previous_level
    append("12:00:00.000 ERROR  RuntimeError: boom", "    app.rb:1:in `go'")
    view.poll

    assert_equal 2, view.rows.size
    assert_equal :error, view.rows[1].level
    assert_includes view.rows[1].text, "app.rb:1"
  end

  # --- truncation / restart reset ---

  def test_file_shrinking_below_offset_resets_and_reparses
    append("12:00:00.000 INFO  old run line 1", "12:00:00.100 INFO  old run line 2")
    view.poll
    assert_equal 2, view.rows.size

    # Target app restarted: truncate-on-open shrank the file.
    File.write(@path, "12:00:01.000 INFO  fresh run\n")
    view.poll

    assert_equal 1, view.rows.size
    assert_includes view.rows[0].text, "fresh run"
  end

  # --- level filter ---

  def test_visible_rows_filters_below_min_level
    append("12:00:00.000 DEBUG  d", "12:00:00.100 INFO  i",
           "12:00:00.200 WARN  w", "12:00:00.300 ERROR  e")
    view.poll
    view.min_level = :warn

    levels = view.visible_rows.map(&:level)
    assert_equal %i[warn error], levels
  end

  def test_cycle_min_level_advances_through_levels
    assert_equal :debug, view.min_level
    view.cycle_min_level
    assert_equal :info, view.min_level
  end

  # --- search filter ---

  def test_query_filters_rows_by_substring
    append("12:00:00.000 INFO  apple", "12:00:00.100 INFO  banana")
    view.poll
    view.query = "ban"

    assert_equal 1, view.visible_rows.size
    assert_includes view.visible_rows[0].text, "banana"
  end

  # --- follow tail ---

  def test_follow_is_on_by_default_and_drops_on_manual_scroll
    assert view.follow?
    view.scroll_up
    refute view.follow?
    view.scroll_to_end
    assert view.follow?
  end

  # --- rendering (exercises the color_for branches for every level) ---

  def test_render_paints_visible_rows_without_raising
    append("12:00:00.000 DEBUG  d-line", "12:00:00.100 INFO  i-line",
           "12:00:00.200 WARN  w-line", "12:00:00.300 ERROR  e-line")
    view.poll

    buffer = Thaum::Rendering::Buffer.new(width: 40, height: 4)
    canvas = Thaum::Rendering::Canvas.new(
      buffer: buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 40, height: 4)
    )
    view.render(canvas: canvas, theme: Thaum::Themes::CATPPUCCIN_MOCHA)

    text = (0...4).map { |y| buffer.row_text(y:) }.join("\n")
    assert_includes text, "w-line"
    assert_includes text, "e-line"
  end
end
