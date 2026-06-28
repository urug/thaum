# frozen_string_literal: true

module Thaum
  module Log
    # The contract every log sink satisfies. `FileSink` is the only
    # implementation today; a future `SocketSink` can drop in behind the
    # same three methods without changing `Thaum.log`.
    #
    #   open         — ready the destination (called once, before first write)
    #   write(line)  — append one pre-formatted line; returns nil
    #   close        — release the destination; writes after close are no-ops
    module Sink
      def open                = raise(NotImplementedError, "#{self.class}#open")
      def write(_line)        = raise(NotImplementedError, "#{self.class}#write")
      def close               = raise(NotImplementedError, "#{self.class}#close")
    end
  end
end
