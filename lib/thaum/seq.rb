# frozen_string_literal: true

module Thaum
  # Sequences for terminal control and input.
  module Seq
    # Mode toggles
    ALT_SCREEN_ON       = "\e[?1049h"
    ALT_SCREEN_OFF      = "\e[?1049l"
    CURSOR_HIDE         = "\e[?25l"
    CURSOR_SHOW         = "\e[?25h"
    BRACKETED_PASTE_ON  = "\e[?2004h"
    BRACKETED_PASTE_OFF = "\e[?2004l"
    SGR_MOUSE_ON        = "\e[?1006h"
    SGR_MOUSE_OFF       = "\e[?1006l"
    CELL_MOTION_ON      = "\e[?1002h"
    CELL_MOTION_OFF     = "\e[?1002l"
    SYNC_BEGIN          = "\e[?2026h"
    SYNC_END            = "\e[?2026l"

    # Select Graphic Rendition (SGR) attributes
    RESET     = "\e[0m"
    BOLD      = "\e[1m"
    DIM       = "\e[2m"
    ITALIC    = "\e[3m"
    UNDERLINE = "\e[4m"

    # Select Graphic Rendition (SGR) named color codes
    FG = {
      black: 30, red: 31, green: 32, yellow: 33,
      blue: 34, magenta: 35, cyan: 36, white: 37,
      bright_black: 90, bright_red: 91, bright_green: 92, bright_yellow: 93,
      bright_blue: 94, bright_magenta: 95, bright_cyan: 96, bright_white: 97,
      default: 39
    }.freeze

    BG = {
      black: 40, red: 41, green: 42, yellow: 43,
      blue: 44, magenta: 45, cyan: 46, white: 47,
      bright_black: 100, bright_red: 101, bright_green: 102, bright_yellow: 103,
      bright_blue: 104, bright_magenta: 105, bright_cyan: 106, bright_white: 107,
      default: 49
    }.freeze

    # Control Sequence Introducer (CSI) input sequences (\e[ + final byte)
    CSI_UP        = "\e[A"
    CSI_DOWN      = "\e[B"
    CSI_RIGHT     = "\e[C"
    CSI_LEFT      = "\e[D"
    CSI_HOME      = "\e[H"
    CSI_END       = "\e[F"
    CSI_SHIFT_TAB = "\e[Z"

    # Single Shift 3 (SS3) input sequences (\eO + final byte) — VT100/application cursor mode
    SS3_F1    = "\eOP"
    SS3_F2    = "\eOQ"
    SS3_F3    = "\eOR"
    SS3_F4    = "\eOS"
    SS3_HOME  = "\eOH"
    SS3_END   = "\eOF"
    SS3_UP    = "\eOA"
    SS3_DOWN  = "\eOB"
    SS3_RIGHT = "\eOC"
    SS3_LEFT  = "\eOD"

    # Tilde input sequences (\e[ + code + ~)
    # F6-F8 skip 16 because some terminals use it for a modifier variant.
    TILDE_HOME      = "\e[1~"
    TILDE_INSERT    = "\e[2~"
    TILDE_DELETE    = "\e[3~"
    TILDE_END       = "\e[4~"
    TILDE_PAGE_UP   = "\e[5~"
    TILDE_PAGE_DOWN = "\e[6~"
    TILDE_F1        = "\e[11~"
    TILDE_F2        = "\e[12~"
    TILDE_F3        = "\e[13~"
    TILDE_F4        = "\e[14~"
    TILDE_F5        = "\e[15~"
    TILDE_F6        = "\e[17~"
    TILDE_F7        = "\e[18~"
    TILDE_F8        = "\e[19~"
    TILDE_F9        = "\e[20~"
    TILDE_F10       = "\e[21~"
    TILDE_F11       = "\e[23~"
    TILDE_F12       = "\e[24~"

    # Dynamic sequences
    def self.cursor_pos(x:, y:) = "\e[#{y};#{x}H"
    def self.color(code) = "\e[#{code}m"
    def self.truecolor(base:, r:, g:, b:) = "\e[#{base};2;#{r};#{g};#{b}m"
  end
end
