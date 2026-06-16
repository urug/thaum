# frozen_string_literal: true

require "test_helper"

class TestThaum < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Thaum::VERSION
  end
end
