# frozen_string_literal: true

module Thaum
  module Log
    # File-backed log sink. Truncates the target on open so each run starts
    # fresh; writes are mutex-guarded because the input-reader thread, the
    # tick timer, and the action pool all log concurrently. Single writer
    # (the app); the companion reader only reads, so no cross-process
    # write contention.
    class FileSink
      include Sink

      def initialize(path)
        @path  = path
        @mutex = Mutex.new
      end

      def open
        @io = File.open(@path, "w")
        @io.sync = true
        self
      end

      def write(line)
        @mutex.synchronize { @io&.write("#{line}\n") }
        nil
      end

      def close
        @io&.close
        @io = nil
      end
    end
  end
end
