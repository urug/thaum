# frozen_string_literal: true

require "test_helper"

class TestTerminal < Minitest::Test
  class FakeInput
    def raw! = nil
    # rows, cols — same order as IO#winsize
    def winsize = [24, 80]
  end

  def setup
    @output = StringIO.new
    @terminal = Thaum::Terminal.new(input: FakeInput.new, output: @output)
  end

  def test_setup_enters_alt_screen_and_hides_cursor
    @terminal.setup
    assert_includes @output.string, "\e[?1049h"
    assert_includes @output.string, "\e[?25l"
  end

  def test_setup_enables_bracketed_paste_and_mouse
    @terminal.setup
    assert_includes @output.string, "\e[?2004h"
    assert_includes @output.string, "\e[?1006h"
    assert_includes @output.string, "\e[?1002h"
  end

  def test_teardown_reverses_setup
    @terminal.setup
    @output.truncate(0)
    @output.rewind
    @terminal.teardown
    written = @output.string
    assert_includes written, "\e[?1002l"
    assert_includes written, "\e[?1006l"
    assert_includes written, "\e[?2004l"
    assert_includes written, "\e[?25h"
    assert_includes written, "\e[?1049l"
  end

  def test_teardown_shows_cursor_before_exiting_alt_screen
    @terminal.setup
    @output.truncate(0)
    @output.rewind
    @terminal.teardown
    written = @output.string
    assert written.index("\e[?25h") < written.index("\e[?1049l"),
           "cursor must be shown before exiting alt screen"
  end

  def test_size_returns_width_height
    assert_equal [80, 24], @terminal.size
  end
end
