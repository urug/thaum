# frozen_string_literal: true

module Thaum
  # Reads raw bytes from an input stream in a background thread and pushes KeyEvents onto a queue.
  class InputReader
    ESCAPE_TIMEOUT = 0.05 # seconds to wait after a bare \e before treating it as Escape

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
      @thread&.join(1)
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
      # If bytes end with a bare ESC, wait briefly — it may be the start of a sequence.
      bytes += @input.readpartial(1024) if bytes.end_with?("\e") && @input.wait_readable(ESCAPE_TIMEOUT)
      bytes
    end
  end
end
