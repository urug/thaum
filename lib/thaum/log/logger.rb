# frozen_string_literal: true

module Thaum
  module Log
    # The currently-active sink for this run, or nil when logging is off.
    # Set by the run loop when `Thaum.run(app, log: path)` is given a path.
    class << self
      attr_accessor :sink

      # Class + message, then each backtrace frame on its own indented line,
      # as one string. Shared by Logger#error and Thaum.safe_invoke so both
      # render exceptions identically.
      def format_exception(error)
        out = "#{error.class}: #{error.message}"
        error.backtrace&.each { |frame| out << "\n    #{frame}" }
        out
      end
    end

    # The object `Thaum.log` returns. Severity methods format a line and hand
    # it to the active sink; they return nil. When no sink is active every
    # call is a cheap no-op and a passed block is never invoked.
    class Logger
      LEVELS = %i[debug info warn error].freeze

      LEVELS.each do |level|
        define_method(level) { |message = nil, &block| write(level, message, &block) }
      end

      private

      def write(level, message, &block)
        sink = Thaum::Log.sink or return nil

        message = block.call if block
        # Whole record (message + any backtrace) is one sink.write — under the
        # sink mutex, so concurrent exceptions can't interleave mid-record.
        message = Thaum::Log.format_exception(message) if message.is_a?(Exception)
        sink.write(format_line(level, message))
        nil
      end

      def format_line(level, message)
        "#{Time.now.strftime('%H:%M:%S.%L')} #{level.to_s.upcase}  #{message}"
      end
    end
  end
end
