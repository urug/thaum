# frozen_string_literal: true

require "test_helper"

class TestColor < Minitest::Test
  # --- Capability detection ---

  def test_detect_truecolor_via_colorterm
    assert_equal :truecolor, Thaum::Color.detect("COLORTERM" => "truecolor", "TERM" => "xterm")
  end

  def test_detect_truecolor_via_24bit
    assert_equal :truecolor, Thaum::Color.detect("COLORTERM" => "24bit", "TERM" => "xterm")
  end

  def test_detect_256_color_via_term
    assert_equal :"256", Thaum::Color.detect("TERM" => "xterm-256color")
  end

  def test_detect_ansi_for_plain_xterm
    assert_equal :ansi, Thaum::Color.detect("TERM" => "xterm")
  end

  def test_detect_none_for_dumb_terminal
    assert_equal :none, Thaum::Color.detect("TERM" => "dumb")
  end

  def test_detect_none_for_empty_env
    assert_equal :none, Thaum::Color.detect({})
  end

  # --- to_escape: truecolor capability ---

  def test_hex_on_truecolor_emits_truecolor_escape
    assert_equal "\e[38;2;255;107;107m",
                 Thaum::Color.to_escape("#ff6b6b", capability: :truecolor, base: 38)
  end

  def test_named_color_on_truecolor_uses_ansi_code
    assert_equal "\e[31m", Thaum::Color.to_escape(:red, capability: :truecolor, base: 38)
  end

  # --- to_escape: 256 capability ---

  def test_hex_on_256_emits_indexed_escape
    out = Thaum::Color.to_escape("#ff6b6b", capability: :"256", base: 38)
    assert_match(/\A\e\[38;5;\d+m\z/, out)
  end

  # --- to_escape: ansi capability ---

  def test_hex_on_ansi_maps_to_nearest_named
    # Pure red maps to :red (sgr 31)
    assert_equal "\e[31m", Thaum::Color.to_escape("#ff0000", capability: :ansi, base: 38)
  end

  def test_hex_on_ansi_pure_white_maps_to_bright_white
    assert_equal "\e[97m", Thaum::Color.to_escape("#ffffff", capability: :ansi, base: 38)
  end

  def test_hex_on_ansi_black_maps_to_black
    assert_equal "\e[30m", Thaum::Color.to_escape("#000000", capability: :ansi, base: 38)
  end

  # --- to_escape: none capability ---

  def test_any_color_on_none_emits_nothing
    assert_equal "", Thaum::Color.to_escape("#ff6b6b", capability: :none, base: 38)
    assert_equal "", Thaum::Color.to_escape(:red,      capability: :none, base: 38)
    assert_equal "", Thaum::Color.to_escape(:default,  capability: :none, base: 38)
  end

  # --- Fallback tuples ---

  def test_fallback_tuple_on_truecolor_uses_hex
    assert_equal "\e[38;2;255;107;107m",
                 Thaum::Color.to_escape(["#ff6b6b", :red], capability: :truecolor, base: 38)
  end

  def test_fallback_tuple_on_ansi_uses_named
    assert_equal "\e[31m",
                 Thaum::Color.to_escape(["#ff6b6b", :red], capability: :ansi, base: 38)
  end

  def test_fallback_tuple_on_256_uses_hex_mapping
    out = Thaum::Color.to_escape(["#ff6b6b", :red], capability: :"256", base: 38)
    assert_match(/\A\e\[38;5;\d+m\z/, out)
  end

  # --- Background base ---

  def test_bg_base_is_used
    assert_equal "\e[48;2;30;30;46m",
                 Thaum::Color.to_escape("#1e1e2e", capability: :truecolor, base: 48)
  end

  # --- Default ---

  def test_default_emits_sgr_default
    assert_equal "\e[39m", Thaum::Color.to_escape(:default, capability: :truecolor, base: 38)
    assert_equal "\e[49m", Thaum::Color.to_escape(:default, capability: :truecolor, base: 48)
  end

  # --- Bad input ---

  def test_unknown_color_emits_nothing
    assert_equal "", Thaum::Color.to_escape("not a color", capability: :truecolor, base: 38)
    assert_equal "", Thaum::Color.to_escape(nil, capability: :truecolor, base: 38)
  end
end
