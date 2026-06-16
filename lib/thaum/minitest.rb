# frozen_string_literal: true

# Optional Minitest integration for Thaum snapshot testing.
#
#   require "thaum/minitest"
#
# Adds assert_snapshot to every Minitest::Test. Snapshots are stored under
# test/snapshots/<name>.txt (plain text) or .ans (ANSI). On the first run
# the fixture is written and the assertion passes; subsequent runs compare
# byte-for-byte. Setting UPDATE_SNAPSHOTS=1 rewrites the fixture in place.

require "fileutils"
require "minitest/assertions"

module Thaum
  module SnapshotMatcher
    SNAPSHOT_ROOT_CANDIDATES = %w[test/snapshots spec/snapshots].freeze
    ANSI_INDICATOR = "\e["

    def assert_snapshot(actual:, name:)
      path = Snapshot.path_for(name: name, actual: actual)
      Snapshot.compare(test: self, actual: actual, path: path, name: name)
    end

    module_function

    def update_mode? = ENV["UPDATE_SNAPSHOTS"] == "1"
  end

  # Internal helpers — not part of the public API.
  module Snapshot
    module_function

    def path_for(name:, actual:)
      ext  = actual.include?(SnapshotMatcher::ANSI_INDICATOR) ? "ans" : "txt"
      root = SnapshotMatcher::SNAPSHOT_ROOT_CANDIDATES.find { |d| Dir.exist?(d) } || "test/snapshots"
      File.join(root, "#{name}.#{ext}")
    end

    def compare(test:, actual:, path:, name:)
      missing = !File.exist?(path)
      if missing || SnapshotMatcher.update_mode?
        write(path: path, actual: actual)
        warn "[Thaum] wrote new snapshot #{name} (#{path})" if missing
        test.assert(true)
        return
      end

      expected = File.read(path)
      test.assert_equal(
        expected, actual,
        "Snapshot \"#{name}\" mismatch (#{path}). " \
        "Run with UPDATE_SNAPSHOTS=1 to rewrite if the new output is correct."
      )
    end

    def write(path:, actual:)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, actual)
    end
  end
end

Minitest::Test.include(Thaum::SnapshotMatcher) if defined?(Minitest::Test)
