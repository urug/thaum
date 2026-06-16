# frozen_string_literal: true

module Thaum
  # Parses raw terminal input bytes into KeyEvent / PasteEvent objects.
  #
  # The parser is stateful: a paste payload that spans multiple parse()
  # calls (chunked reads from the InputReader) is accumulated across calls
  # and emitted as a single PasteEvent once the closing \e[201~ marker
  # arrives. The class-level .parse helper makes a fresh instance for
  # one-shot use.
  class EscapeParser
    PASTE_START = "\e[200~"
    PASTE_END   = "\e[201~"

    # Ground state byte codes
    CR = 0x0d     # Carriage return
    LF = 0x0a     # Line feed
    TAB = 0x09    # Tab
    DEL = 0x7f    # Delete
    BS = 0x08     # Backspace
    CTRL_START = 0x01
    CTRL_END = 0x1a
    PRINTABLE_START = 0x20
    PRINTABLE_END = 0x7e

    # Escape sequence byte codes
    ESC = 0x1b
    SGR_MOUSE_MARKER = 0x3c  # '<' for SGR mouse introducer
    SGR_MOUSE_PRESS = 0x4d   # 'M'
    SGR_MOUSE_RELEASE = 0x6d # 'm'
    CSI_FINAL_START = 0x40
    CSI_FINAL_END = 0x7e
    SGR_DIGIT_START = 0x30   # '0'
    SGR_DIGIT_END = 0x39     # '9'
    SGR_SEP = 0x3b           # ';'

    def self.parse(input) = new.parse(input)

    def initialize
      @paste_buf = nil
    end

    def parse(input)
      events = []
      i = 0
      while i < input.bytesize
        if @paste_buf
          i = collect_paste(input: input, i: i, events: events)
        elsif input.getbyte(i) == ESC
          i = parse_at_escape(input: input, i: i, events: events)
        else
          event = parse_ground(input.getbyte(i))
          events << event if event
          i += 1
        end
      end
      events
    end

    private

    # Inside a paste — look for PASTE_END from position i. Returns the
    # index to resume parsing from (just past PASTE_END, or bytesize if
    # the terminator hasn't arrived yet).
    def collect_paste(input:, i:, events:)
      end_idx = input.byteindex(PASTE_END, i)
      if end_idx
        @paste_buf << input.byteslice(i, end_idx - i)
        events << PasteEvent.new(text: @paste_buf)
        @paste_buf = nil
        end_idx + PASTE_END.bytesize
      else
        @paste_buf << input.byteslice(i, input.bytesize - i)
        input.bytesize
      end
    end

    # ESC at position i. Either paste-start, paste-end (stray — ignored as
    # a bare :escape), or a normal escape sequence. Returns the next index.
    def parse_at_escape(input:, i:, events:)
      if input.byteslice(i, PASTE_START.bytesize) == PASTE_START
        @paste_buf = +""
        return i + PASTE_START.bytesize
      end

      event, consumed = parse_escape_at(input: input, i: i)
      events << event if event
      i + consumed
    end

    # Returns [KeyEvent, bytes_consumed] starting from position i (the ESC byte).
    def parse_escape_at(input:, i:)
      next_pos = i + 1
      return [KeyEvent.new(key: :escape), 1] if next_pos >= input.bytesize

      case input.getbyte(next_pos)
      when Seq::CSI_UP.getbyte(1) then parse_csi_at(input: input, i: i)   # Control Sequence Introducer (CSI): 0x5b [
      when Seq::SS3_UP.getbyte(1) then parse_ss3_at(input: input, i: i)   # Single Shift 3 (SS3): 0x4f O
      else
        # Alt + whatever the next ground byte produces
        event = parse_ground(input.getbyte(next_pos))
        if event
          [KeyEvent.new(key: event.key, alt: true), 2]
        else
          [KeyEvent.new(key: :escape), 1]
        end
      end
    end

    # i points to ESC; input[i+1] == '[' (Control Sequence Introducer).
    def parse_csi_at(input:, i:)
      # SGR mouse: ESC [ < Cb ; Cx ; Cy (M|m)
      return parse_sgr_mouse_at(input: input, i: i) if input.getbyte(i + 2) == SGR_MOUSE_MARKER

      j = i + 2
      params_start = j
      while j < input.bytesize
        b = input.getbyte(j)
        if b.between?(CSI_FINAL_START, CSI_FINAL_END)
          params = input.byteslice(params_start, j - params_start)
          final  = b.chr
          return [decode_csi(params: params, final: final), j - i + 1]
        end
        j += 1
      end
      [KeyEvent.new(key: :escape), 1]
    end

    # i points to ESC; input[i+1] == '['; input[i+2] == '<'. Scan to the
    # final byte (M or m) and decode an SGR mouse event.
    def parse_sgr_mouse_at(input:, i:)
      j = i + 3
      params_start = j
      while j < input.bytesize
        b = input.getbyte(j)
        if [SGR_MOUSE_PRESS, SGR_MOUSE_RELEASE].include?(b)
          params = input.byteslice(params_start, j - params_start)
          final  = b.chr
          # Well-formed SGR sequence — consume it whether or not we emit.
          # decode_sgr_mouse returns nil for events we intentionally drop.
          return [decode_sgr_mouse(params: params, final: final), j - i + 1]
        end
        # SGR mouse params are digits and ';'. Bail out if we see anything else.
        break unless b.between?(SGR_DIGIT_START, SGR_DIGIT_END) || b == SGR_SEP

        j += 1
      end
      [KeyEvent.new(key: :escape), 1]
    end

    def decode_sgr_mouse(params:, final:)
      parts = params.split(";")
      return nil if parts.size != 3

      cb = parts[0].to_i
      cx = parts[1].to_i
      cy = parts[2].to_i

      shift = cb.anybits?(4)
      alt   = cb.anybits?(8)
      ctrl  = cb.anybits?(16)
      motion = cb.anybits?(32)
      wheel  = cb.anybits?(64)
      btn_bits = cb & 0b11

      button, action = button_and_action(btn_bits: btn_bits, final: final, wheel: wheel, motion: motion)
      return nil if action == :invalid

      # SGR coords are 1-based; convert to 0-based.
      ax = cx - 1
      ay = cy - 1
      MouseEvent.new(button: button, action: action, abs_x: ax, abs_y: ay,
                     shift: shift, alt: alt, ctrl: ctrl)
    end

    def button_from_bits(btn_bits)
      case btn_bits
      when 0 then :left
      when 1 then :middle
      when 2 then :right
      end
    end

    def button_and_action(btn_bits:, final:, wheel:, motion:)
      if wheel
        button = btn_bits.zero? ? :wheel_up : :wheel_down
        [button, :scroll]
      elsif final == "m"
        # Release. SGR encodes the released button in the low bits;
        # value 3 historically means "unknown" — leave button nil.
        [button_from_bits(btn_bits), :release]
      elsif motion
        # Under button-event tracking (1002), motion arrives only while a
        # button is held → :drag. btn_bits == 3 (no button) shouldn't occur;
        # drop it if it does.
        button = button_from_bits(btn_bits)
        button ? [button, :drag] : [nil, :invalid]
      else
        button = button_from_bits(btn_bits)
        return [nil, :invalid] unless button # btn_bits == 3 with no motion bit is unspecified

        [button, :press]
      end
    end

    # i points to ESC; input[i+1] == 'O' (Single Shift 3).
    def parse_ss3_at(input:, i:)
      pos = i + 2
      return [KeyEvent.new(key: :escape), 1] if pos >= input.bytesize

      key = Keys::SS3[input.getbyte(pos).chr]
      key ? [KeyEvent.new(key: key), 3] : [KeyEvent.new(key: :escape), 1]
    end

    def decode_csi(params:, final:)
      case final
      when Seq::CSI_SHIFT_TAB[-1]
        KeyEvent.new(key: :tab, shift: true)
      when "~"
        parts = params.split(";")
        key   = Keys::TILDE[parts[0].to_i]
        return KeyEvent.new(key: :escape) unless key

        mod = parts[1]&.to_i
        mod ? KeyEvent.new(key: key, **modifier_flags(mod)) : KeyEvent.new(key: key)
      else
        key = Keys::CSI[final]
        return KeyEvent.new(key: :escape) unless key

        if params.include?(";")
          mod = params.split(";")[1]&.to_i
          mod ? KeyEvent.new(key: key, **modifier_flags(mod)) : KeyEvent.new(key: key)
        else
          KeyEvent.new(key: key)
        end
      end
    end

    def parse_ground(byte)
      case byte
      when CR, LF
        KeyEvent.new(key: :enter)
      when TAB
        KeyEvent.new(key: :tab)
      when DEL, BS
        KeyEvent.new(key: :backspace)
      when CTRL_START..CTRL_END
        KeyEvent.new(key: (byte + 96).chr, ctrl: true)
      when PRINTABLE_START..PRINTABLE_END
        KeyEvent.new(key: byte.chr)
      end
    end

    # xterm modifier encoding: param = bitflags + 1
    # bit 0 = shift, bit 1 = alt, bit 2 = ctrl
    def modifier_flags(mod)
      flags = mod - 1
      {
        shift: flags.anybits?(1),
        alt: flags.anybits?(2),
        ctrl: flags.anybits?(4)
      }
    end
  end
end
