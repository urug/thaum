# frozen_string_literal: true

require "io/console"

module Thaum
  # Manages terminal setup and teardown: alternate screen, cursor, mouse, and bracketed paste.
  class Terminal
    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
    end

    def setup
      @original_stty = stty_save
      @input.raw!
      write Seq::ALT_SCREEN_ON
      write Seq::CURSOR_HIDE
      write Seq::BRACKETED_PASTE_ON
      write Seq::SGR_MOUSE_ON
      write Seq::CELL_MOTION_ON
    end

    def teardown
      write Seq::CELL_MOTION_OFF
      write Seq::SGR_MOUSE_OFF
      write Seq::BRACKETED_PASTE_OFF
      write Seq::CURSOR_SHOW
      write Seq::ALT_SCREEN_OFF
      stty_restore(@original_stty)
    end

    def size
      rows, cols = @input.winsize
      [cols, rows]
    end

    private

    def write(str) = @output.write(str)
    def stty_save = @input.respond_to?(:tty?) && @input.tty? ? `stty -g 2>/dev/null`.chomp : ""

    def stty_restore(state)
      system("stty", state) if state && !state.empty?
    end
  end
end
