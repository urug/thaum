# frozen_string_literal: true

require "test_helper"

class TestBoxDrawing < Minitest::Test
  M = Thaum::Rendering::BoxDrawing

  # ----- Pure merges -------------------------------------------------------

  def test_horizontal_meets_vertical_is_cross
    assert_equal "┼", M.merge(existing: "─", incoming: "│")
    assert_equal "┼", M.merge(existing: "│", incoming: "─")
  end

  def test_same_glyph_is_idempotent
    %w[─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼].each do |glyph|
      assert_equal glyph, M.merge(existing: glyph, incoming: glyph), "#{glyph} should be idempotent"
    end
  end

  def test_corner_meets_horizontal_is_tee
    # ┌ has down + right; ─ adds left.
    assert_equal "┬", M.merge(existing: "┌", incoming: "─")
    # └ has up + right; ─ adds left.
    assert_equal "┴", M.merge(existing: "└", incoming: "─")
  end

  def test_corner_meets_vertical_is_tee
    # ┌ has down + right; │ adds up + down (down already there).
    assert_equal "├", M.merge(existing: "┌", incoming: "│")
    # ┐ has down + left; │ adds up.
    assert_equal "┤", M.merge(existing: "┐", incoming: "│")
  end

  def test_two_corners_meeting_at_a_cell_form_tee
    # ┌ (down+right) + ┐ (down+left) = down+left+right = ┬
    assert_equal "┬", M.merge(existing: "┌", incoming: "┐")
    # └ (up+right) + ┘ (up+left) = up+left+right = ┴
    assert_equal "┴", M.merge(existing: "└", incoming: "┘")
  end

  def test_tee_meets_perpendicular_line_is_cross
    # ├ (up+down+right) + ─ (left+right) = up+down+left+right = ┼
    assert_equal "┼", M.merge(existing: "├", incoming: "─")
  end

  def test_half_stub_meets_line_extends
    # ╴ (left) + ─ (left+right) = left+right = ─
    assert_equal "─", M.merge(existing: "╴", incoming: "─")
    # ╵ (up) + │ (up+down) = up+down = │
    assert_equal "│", M.merge(existing: "╵", incoming: "│")
  end

  def test_two_perpendicular_stubs_form_a_corner
    # ╶ (right) + ╷ (down) = down+right = ┌
    assert_equal "┌", M.merge(existing: "╶", incoming: "╷")
  end

  # ----- Rounded corners ---------------------------------------------------

  def test_rounded_corner_shares_segments_with_regular_corner
    # ╭ has same segments as ┌; merging in a vertical produces a tee.
    assert_equal "├", M.merge(existing: "╭", incoming: "│")
  end

  def test_rounded_corner_idempotent_returns_canonical_glyph
    # Two ╭ writes — both have segments [0,1,0,1]. The canonical glyph
    # for that signature is ┌ (rounded info is lost on merge).
    assert_equal "┌", M.merge(existing: "╭", incoming: "╭")
  end

  # ----- Fallbacks --------------------------------------------------------

  def test_non_box_existing_is_overwritten
    # Cell holds plain text; writing a box char replaces it.
    assert_equal "│", M.merge(existing: "h", incoming: "│")
  end

  def test_non_box_incoming_overwrites_box
    # Cell holds a box char; writing text replaces it.
    assert_equal "h", M.merge(existing: "│", incoming: "h")
  end

  def test_space_is_not_a_box_char
    assert_equal "│", M.merge(existing: " ", incoming: "│")
    assert_equal " ", M.merge(existing: "│", incoming: " ")
  end

  # ----- Pure heavy -------------------------------------------------------

  def test_heavy_horizontal_meets_heavy_vertical_is_heavy_cross
    assert_equal "╋", M.merge(existing: "━", incoming: "┃")
    assert_equal "╋", M.merge(existing: "┃", incoming: "━")
  end

  def test_heavy_corner_meets_heavy_horizontal_is_heavy_tee
    # ┏ (d2, r2) + ━ (l2, r2) = (0,2,2,2) = ┳
    assert_equal "┳", M.merge(existing: "┏", incoming: "━")
    # ┗ (u2, r2) + ━ = ┻
    assert_equal "┻", M.merge(existing: "┗", incoming: "━")
  end

  def test_heavy_corner_meets_heavy_vertical_is_heavy_tee
    assert_equal "┣", M.merge(existing: "┏", incoming: "┃")
    assert_equal "┫", M.merge(existing: "┓", incoming: "┃")
  end

  def test_heavy_two_corners_form_heavy_tee
    assert_equal "┳", M.merge(existing: "┏", incoming: "┓")
    assert_equal "┻", M.merge(existing: "┗", incoming: "┛")
  end

  def test_heavy_tee_meets_perpendicular_heavy_line_is_heavy_cross
    assert_equal "╋", M.merge(existing: "┣", incoming: "━")
  end

  def test_heavy_half_stubs_form_heavy_corner
    # ╺ (r2) + ╻ (d2) = (0,2,0,2) = ┏
    assert_equal "┏", M.merge(existing: "╺", incoming: "╻")
    # ╹ (u2) + ╸ (l2) = (2,0,2,0) = ┛
    assert_equal "┛", M.merge(existing: "╹", incoming: "╸")
  end

  def test_heavy_idempotent
    %w[━ ┃ ┏ ┓ ┗ ┛ ┣ ┫ ┳ ┻ ╋].each do |glyph|
      assert_equal glyph, M.merge(existing: glyph, incoming: glyph), "#{glyph} should be idempotent"
    end
  end

  # ----- Pure double ------------------------------------------------------

  def test_double_horizontal_meets_double_vertical_is_double_cross
    assert_equal "╬", M.merge(existing: "═", incoming: "║")
    assert_equal "╬", M.merge(existing: "║", incoming: "═")
  end

  def test_double_corner_meets_double_line_is_double_tee
    # ╔ (d3, r3) + ═ (l3, r3) = (0,3,3,3) = ╦
    assert_equal "╦", M.merge(existing: "╔", incoming: "═")
    # ╔ + ║ = ╠
    assert_equal "╠", M.merge(existing: "╔", incoming: "║")
  end

  def test_double_two_corners_form_double_tee
    assert_equal "╦", M.merge(existing: "╔", incoming: "╗")
    assert_equal "╩", M.merge(existing: "╚", incoming: "╝")
  end

  def test_double_tee_meets_perpendicular_double_line_is_double_cross
    assert_equal "╬", M.merge(existing: "╠", incoming: "═")
  end

  def test_double_idempotent
    %w[═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬].each do |glyph|
      assert_equal glyph, M.merge(existing: glyph, incoming: glyph), "#{glyph} should be idempotent"
    end
  end

  # ----- Light meeting heavy (mixed-weight glyphs) ------------------------

  def test_light_horizontal_meets_heavy_vertical_is_mixed_cross
    # ─ (l1, r1) + ┃ (u2, d2) = (2,2,1,1) = ╂
    assert_equal "╂", M.merge(existing: "─", incoming: "┃")
  end

  def test_heavy_horizontal_meets_light_vertical_is_mixed_cross
    # ━ (l2, r2) + │ (u1, d1) = (1,1,2,2) = ┿
    assert_equal "┿", M.merge(existing: "━", incoming: "│")
  end

  def test_light_corner_meets_heavy_horizontal_is_mixed_top_tee
    # ┌ (d1, r1) + ━ (l2, r2) = (0,1,2,2) = ┯
    assert_equal "┯", M.merge(existing: "┌", incoming: "━")
  end

  def test_heavy_corner_meets_light_horizontal_is_mixed_top_tee
    # ┏ (d2, r2) + ─ (l1, r1) = (0,2,1,2) = ┲ (l light, r stays heavy)
    assert_equal "┲", M.merge(existing: "┏", incoming: "─")
    # ┓ (d2, l2) + ─ = (0,2,2,1) = ┱
    assert_equal "┱", M.merge(existing: "┓", incoming: "─")
  end

  def test_light_corner_meets_heavy_vertical_is_mixed_left_tee
    # ┌ (d1, r1) + ┃ (u2, d2) = (2,2,0,1) = ┠
    assert_equal "┠", M.merge(existing: "┌", incoming: "┃")
  end

  def test_heavy_corner_meets_light_vertical_is_mixed_left_tee
    # ┏ (d2, r2) + │ (u1, d1) = (1,2,0,2) = ┢
    assert_equal "┢", M.merge(existing: "┏", incoming: "│")
  end

  def test_mixed_corner_idempotent_returns_itself
    # ┍ has (0,1,0,2); pre-built mixed corners should round-trip.
    %w[┍ ┎ ┑ ┒ ┕ ┖ ┙ ┚].each do |glyph|
      assert_equal glyph, M.merge(existing: glyph, incoming: glyph)
    end
  end

  def test_same_direction_heavy_promotes_over_light
    # Per-direction max: light meeting heavy in the same direction
    # promotes the segment to heavy.
    assert_equal "━", M.merge(existing: "─", incoming: "━")
    assert_equal "┃", M.merge(existing: "│", incoming: "┃")
  end

  # ----- Light meeting double (mixed-weight glyphs) -----------------------

  def test_light_horizontal_meets_double_vertical_is_mixed_cross
    # ─ + ║ = (3,3,1,1) = ╫
    assert_equal "╫", M.merge(existing: "─", incoming: "║")
  end

  def test_double_horizontal_meets_light_vertical_is_mixed_cross
    # ═ + │ = (1,1,3,3) = ╪
    assert_equal "╪", M.merge(existing: "═", incoming: "│")
  end

  def test_light_corner_meets_double_horizontal_is_mixed_top_tee
    # ┌ (d1, r1) + ═ (l3, r3) = (0,1,3,3) = ╤
    assert_equal "╤", M.merge(existing: "┌", incoming: "═")
  end

  def test_mixed_double_corner_meets_light_horizontal_is_mixed_top_tee
    # ╓ (d3, r1) + ─ (l1, r1) = (0,3,1,1) = ╥
    assert_equal "╥", M.merge(existing: "╓", incoming: "─")
    # ╖ (d3, l1) + ─ = (0,3,1,1) = ╥
    assert_equal "╥", M.merge(existing: "╖", incoming: "─")
  end

  def test_same_direction_double_promotes_over_light
    assert_equal "═", M.merge(existing: "─", incoming: "═")
    assert_equal "║", M.merge(existing: "│", incoming: "║")
  end

  # ----- Heavy + double: no Unicode glyph, fall back to incoming ---------

  def test_heavy_vertical_meets_double_horizontal_falls_back
    # ┃ (u2, d2) + ═ (l3, r3) = (2,2,3,3) — no Unicode glyph exists.
    # merge should return the incoming char.
    assert_equal "═", M.merge(existing: "┃", incoming: "═")
    assert_equal "┃", M.merge(existing: "═", incoming: "┃")
  end

  def test_double_vertical_meets_heavy_horizontal_falls_back
    # ║ (u3, d3) + ━ (l2, r2) = (3,3,2,2) — no glyph.
    assert_equal "━", M.merge(existing: "║", incoming: "━")
    assert_equal "║", M.merge(existing: "━", incoming: "║")
  end

  def test_heavy_corner_meets_double_line_falls_back
    # ┏ (d2, r2) + ═ (l3, r3) = (0,2,3,3) — no glyph.
    assert_equal "═", M.merge(existing: "┏", incoming: "═")
  end

  def test_same_direction_heavy_meets_double_promotes_to_double
    # Per-direction max: where both segments are present, double > heavy.
    # ━ + ═ → both have l/r set, double wins. Result is ═.
    assert_equal "═", M.merge(existing: "━", incoming: "═")
    assert_equal "║", M.merge(existing: "┃", incoming: "║")
  end

  # ----- Rounded corner behaviour preserved ------------------------------

  def test_rounded_corner_still_canonicalises_to_light_corner
    # Rounded ╭ + ╮ = (0,1,1,1) = ┬ (light tee), not a rounded glyph.
    assert_equal "┬", M.merge(existing: "╭", incoming: "╮")
  end
end
