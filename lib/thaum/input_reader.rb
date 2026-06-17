# frozen_string_literal: true

module Thaum
  # Reads raw bytes from an input stream in a background thread and pushes KeyEvents onto a queue.
  class InputReader
    ESCAPE_TIMEOUT = 0.05 # seconds to wait after a bare \e before treating it as Escape
    MAX_ESCAPE_EXTENDS = 4 # cap extend reads so malformed input can't hang the reader

    ESC = "\e"
    CSI_INTRO   = 0x5b  # '[' — Control Sequence Introducer
    SS3_INTRO   = 0x4f  # 'O' — Single Shift 3
    SGR_MOUSE_MARKER = 0x3c # '<' — SGR mouse introducer
    CSI_FINAL_RANGE  = 0x40..0x7e # any byte in this range terminates a CSI
    SGR_MOUSE_FINAL  = [0x4d, 0x6d].freeze # 'M' / 'm' terminate an SGR mouse sequence

    def initialize(input:, queue:, parser: EscapeParser.new)
      @input  = input
      @queue  = queue
      @parser = parser
      @thread = nil
    end

    def start
      @thread = Thread.new { run }
    end

    def stop
      return unless @thread

      # Give the thread a moment to finish on its own (e.g. input already closed).
      # If it's still blocked in readpartial, interrupt it so stop doesn't wait out
      # the full join timeout (~1s) on every quit.
      @thread.kill unless @thread.join(0.1)
      @thread.join(1)
      @thread = nil
    end

    def alive?
      @thread&.alive? || false
    end

    private

    def run
      loop do
        bytes = read_chunk
        @parser.parse(bytes).each { |event| @queue.push(event) }
      end
    rescue IOError
      # input closed — exit cleanly
    end

    def read_chunk
      bytes = @input.readpartial(1024)
      # The chunk may end in the middle of an escape sequence (a bare ESC, or
      # an in-progress CSI/SS3/mouse sequence whose final byte hasn't arrived).
      # Extend the read while that's the case and more bytes are available,
      # bounded by MAX_ESCAPE_EXTENDS so malformed input can't hang the reader.
      # A genuinely-bare ESC keypress resolves to :escape once wait_readable
      # times out (no more bytes) and we return what we have.
      extends = 0
      while pending_escape?(bytes) && extends < MAX_ESCAPE_EXTENDS && @input.wait_readable(ESCAPE_TIMEOUT)
        bytes += @input.readpartial(1024)
        extends += 1
      end
      bytes
    end

    # True when `bytes` ends with an incomplete escape sequence — a trailing
    # ESC that the parser cannot yet dispatch as a complete sequence. Covers
    # the three forms the parser recognizes: CSI (\e[ … final byte 0x40–0x7e,
    # with SGR mouse \e[< … terminated by M/m), SS3 (\eO needs one more byte),
    # and a lone trailing ESC. A complete bracketed-paste START (\e[200~) is
    # NOT pending — paste accumulation is handled statefully by the parser.
    def pending_escape?(bytes)
      esc = bytes.byterindex(ESC)
      return false if esc.nil?

      # A complete bracketed-paste START (\e[200~) is treated as a normal,
      # dispatchable CSI here (its '~' is a CSI final byte), so it is NOT
      # pending — the parser takes over paste accumulation statefully. A
      # *partial* marker (e.g. \e[2 / \e[200) is an incomplete CSI and stays
      # pending so we keep reading until the '~' arrives.
      tail = bytes.byteslice(esc, bytes.bytesize - esc)
      incomplete_escape_tail?(tail)
    end

    # `tail` starts at an ESC byte. Returns true if it is NOT yet a complete,
    # dispatchable escape sequence.
    def incomplete_escape_tail?(tail)
      return true if tail.bytesize == 1 # lone trailing ESC

      case tail.getbyte(1)
      when CSI_INTRO then incomplete_csi_tail?(tail)
      when SS3_INTRO then tail.bytesize < 3 # \eO needs exactly one more byte
      else false # \e + ground byte (Alt+key) is complete in two bytes
      end
    end

    # `tail` begins with \e[. SGR mouse (\e[<) terminates on M/m; a plain CSI
    # terminates on any byte in 0x40–0x7e. Incomplete until that final byte.
    def incomplete_csi_tail?(tail)
      return true if tail.bytesize == 2 # just "\e[" so far

      sgr = tail.getbyte(2) == SGR_MOUSE_MARKER
      body_start = sgr ? 3 : 2
      body = tail.byteslice(body_start, tail.bytesize - body_start)
      body.each_byte.none? { |b| csi_final?(b, sgr: sgr) }
    end

    def csi_final?(byte, sgr:)
      sgr ? SGR_MOUSE_FINAL.include?(byte) : CSI_FINAL_RANGE.cover?(byte)
    end
  end
end
