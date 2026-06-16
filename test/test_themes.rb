# frozen_string_literal: true

require "test_helper"

class TestThemes < Minitest::Test
  def test_default_theme_has_semantic_tokens
    t = Thaum::Themes::DEFAULT

    refute_nil t.success_fg
    refute_nil t.warning_fg
    refute_nil t.error_fg
    refute_nil t.info_fg
    refute_nil t.muted_fg
    refute_nil t.disabled_fg
  end

  def test_theme_new_back_compat_defaults_semantic_tokens
    t = Thaum::Theme.new(
      bg: "#000000",
      fg: "#ffffff",
      accent: "#00aaff",
      border: "#333333",
      dim: "#777777",
      selection: "#111111",
      selection_fg: "#ffffff",
      pressed: "#090909",
      input_bg: "#090909",
      bar_bg: "#050505"
    )

    assert_equal t.accent, t.success_fg
    assert_equal t.accent, t.warning_fg
    assert_equal t.accent, t.error_fg
    assert_equal t.accent, t.info_fg
    assert_equal t.dim, t.muted_fg
    assert_equal t.dim, t.disabled_fg
  end

  def test_names_match_lookup_keys
    assert_equal Thaum::Themes::BY_NAME.keys, Thaum::Themes.names
  end

  def test_lookup_raises_for_unknown_theme
    err = assert_raises(ArgumentError) { Thaum::Themes[:nope] }
    assert_match(/unknown theme/, err.message)
  end

  def test_validation_rejects_bad_contrast
    bad = Thaum::Theme.new(
      bg: "#111111",
      fg: "#111111",
      accent: "#222222",
      border: "#222222",
      dim: "#222222",
      selection: "#111111",
      selection_fg: "#111111",
      pressed: "#111111",
      input_bg: "#111111",
      bar_bg: "#111111"
    )

    assert_raises(ArgumentError) do
      Thaum::Themes.send(:validate_theme!, :bad, bad)
    end
  end
end
