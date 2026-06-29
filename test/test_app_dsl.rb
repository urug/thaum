# frozen_string_literal: true

require "test_helper"

# Quick-start entry points for Thaum::App: the `.run` class method and
# `Thaum.app { }`.
class TestAppDSL < Minitest::Test
  def test_include_adds_run_class_method
    klass = Class.new { include Thaum::App }
    assert_respond_to klass, :run
  end

  # The happy path enters the blocking run loop (no headless harness yet, and
  # the suite doesn't stub), so it's exercised by examples/hello_world.rb. Here
  # we only pin the missing-block guard, which needs no terminal.
  def test_app_requires_a_block
    assert_raises(ArgumentError) { Thaum.app }
  end
end
