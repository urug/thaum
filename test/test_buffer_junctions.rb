# frozen_string_literal: true

require "test_helper"

# Buffer#set merges box-drawing chars on top of existing box-drawing
# chars rather than overwriting. Adjacent Canvas#border calls that
# share an edge therefore produce correct junction glyphs.
class TestBufferJunctions < Minitest::Test
  def setup
    @buf = Thaum::Rendering::Buffer.new(width: 20, height: 6)
  end

  def at(x:, y:) = @buf.cell(x: x, y: y).char

  def test_set_box_char_on_box_char_merges
    @buf.set(x: 0, y: 0, char: "─")
    @buf.set(x: 0, y: 0, char: "│")
    assert_equal "┼", at(x: 0, y: 0)
  end

  def test_set_non_box_overwrites_box
    @buf.set(x: 0, y: 0, char: "┼")
    @buf.set(x: 0, y: 0, char: "H")
    assert_equal "H", at(x: 0, y: 0)
  end

  def test_set_box_overwrites_non_box
    @buf.set(x: 0, y: 0, char: "H")
    @buf.set(x: 0, y: 0, char: "│")
    assert_equal "│", at(x: 0, y: 0)
  end

  def test_set_box_on_empty_cell_stays_as_written
    @buf.set(x: 0, y: 0, char: "┌")
    assert_equal "┌", at(x: 0, y: 0)
  end

  def test_adjacent_borders_share_top_edge
    # Two side-by-side 4-wide × 3-tall boxes, drawn so their corners
    # share a column. Expected layout:
    #   ┌──┬──┐
    #   │  │  │
    #   └──┴──┘
    buf   = Thaum::Rendering::Buffer.new(width: 7, height: 3)
    left  = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 4, height: 3))
    right = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 3, y: 0, width: 4, height: 3))
    left.border
    right.border

    assert_equal "┌──┬──┐", buf.row_text(y: 0)
    assert_equal "│  │  │", buf.row_text(y: 1)
    assert_equal "└──┴──┘", buf.row_text(y: 2)
  end

  def test_stacked_borders_share_left_edge
    # Two stacked boxes sharing a horizontal edge. Expected:
    #   ┌────┐
    #   │    │
    #   ├────┤
    #   │    │
    #   └────┘
    buf    = Thaum::Rendering::Buffer.new(width: 6, height: 5)
    top    = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 6, height: 3))
    bottom = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 2, width: 6, height: 3))
    top.border
    bottom.border

    assert_equal "┌────┐", buf.row_text(y: 0)
    assert_equal "│    │", buf.row_text(y: 1)
    assert_equal "├────┤", buf.row_text(y: 2)
    assert_equal "│    │", buf.row_text(y: 3)
    assert_equal "└────┘", buf.row_text(y: 4)
  end

  def test_adjacent_thick_and_single_borders_form_mixed_junctions
    # A thick (heavy) box on the left sharing a column with a single
    # (light) box on the right. The shared column should produce
    # mixed light/heavy junction glyphs.
    buf   = Thaum::Rendering::Buffer.new(width: 7, height: 3)
    left  = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 4, height: 3))
    right = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 3, y: 0, width: 4, height: 3))
    left.border(style: :thick)
    right.border(style: :single)

    # Top row: ┏━━ + ┌──┐ overlapped at x=3.
    # x=3 cell: ┓ (heavy d+l) merged with ┌ (light d+r) =
    #   (0,2,2,1) = ┱
    assert_equal "┏━━┱──┐", buf.row_text(y: 0)
    # Middle row: ┃ (heavy v) + │ (light v) merged at x=3 = ┃
    assert_equal "┃  ┃  │", buf.row_text(y: 1)
    # Bottom: ┛ (heavy u+l) + └ (light u+r) = (2,0,2,1) = ┹
    assert_equal "┗━━┹──┘", buf.row_text(y: 2)
  end

  def test_stacked_thick_and_single_borders_form_mixed_junctions
    # Thick box on top of a single box, sharing a horizontal edge.
    buf    = Thaum::Rendering::Buffer.new(width: 6, height: 5)
    top    = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 0, width: 6, height: 3))
    bottom = Thaum::Rendering::Canvas.new(buffer: buf, rect: Thaum::Rect.new(x: 0, y: 2, width: 6, height: 3))
    top.border(style: :thick)
    bottom.border(style: :single)

    # Shared row at y=2: top's bottom is ┗━━━━┛ (heavy), bottom's top
    # is ┌────┐ (light). Left corner: ┗+┌=┡, right ┛+┐=┩, mid: ━+─=━.
    assert_equal "┡━━━━┩", buf.row_text(y: 2)
  end

  def test_four_quadrants_meet_at_a_cross
    # 2×2 grid of boxes sharing a center cell.
    coords = [[0, 0], [3, 0], [0, 2], [3, 2]]
    coords.each do |x, y|
      Thaum::Rendering::Canvas.new(buffer: @buf, rect: Thaum::Rect.new(x: x, y: y, width: 4, height: 3)).border
    end

    # Center column (x=3) should have: ┬ at y=0, │ at y=1, ┼ at y=2, │ at y=3, ┴ at y=4
    assert_equal "┬", at(x: 3, y: 0)
    assert_equal "│", at(x: 3, y: 1)
    assert_equal "┼", at(x: 3, y: 2)
    assert_equal "│", at(x: 3, y: 3)
    assert_equal "┴", at(x: 3, y: 4)
  end
end
