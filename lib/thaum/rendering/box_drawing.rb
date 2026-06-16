# frozen_string_literal: true

module Thaum
  # Segment-bitmap merging for Unicode box-drawing characters.
  #
  # Each known glyph is encoded as four directional segment weights:
  # [up, down, left, right]. Weights are 0 (none), 1 (light), 2 (heavy),
  # 3 (double). When two glyphs are merged the result's weights are the
  # per-direction max of the inputs, looked up back to a canonical glyph.
  #
  # Coverage:
  # - Light family (U+2500-U+2503, U+250C-U+253C, half-stubs)
  # - Heavy family (U+2501, U+2503, U+250F, U+2513, U+2517, U+251B,
  #   U+2523, U+252B, U+2533, U+253B, U+254B, U+2578-U+257B)
  # - Mixed light/heavy (U+250D-U+250F minus 250C, U+2511-U+2513 minus
  #   2510, etc. — full U+250C-U+254B region)
  # - Double family (U+2550, U+2551, U+2554, U+2557, U+255A, U+255D,
  #   U+2560, U+2563, U+2566, U+2569, U+256C)
  # - Mixed light/double (U+2552, U+2553, U+2555, U+2556, U+2558,
  #   U+2559, U+255B, U+255C, U+255E-U+256B)
  # - Rounded corners (U+256D-U+2570) — share segments with non-rounded
  #   light corners; merges return the non-rounded canonical glyph.
  #
  # Heavy + double in different directions has no Unicode glyph; merge
  # falls through to "incoming wins."
  module Rendering
    module BoxDrawing
      # char => [up, down, left, right] weights (0=none, 1=light, 2=heavy, 3=double)
      SEGMENTS = {
        # ----- Pure light --------------------------------------------------
        "─" => [0, 0, 1, 1],
        "│" => [1, 1, 0, 0],
        "┌" => [0, 1, 0, 1],
        "┐" => [0, 1, 1, 0],
        "└" => [1, 0, 0, 1],
        "┘" => [1, 0, 1, 0],
        "├" => [1, 1, 0, 1],
        "┤" => [1, 1, 1, 0],
        "┬" => [0, 1, 1, 1],
        "┴" => [1, 0, 1, 1],
        "┼" => [1, 1, 1, 1],
        "╴" => [0, 0, 1, 0],
        "╵" => [1, 0, 0, 0],
        "╶" => [0, 0, 0, 1],
        "╷" => [0, 1, 0, 0],
        # Rounded corners share signatures with the non-rounded corners.
        "╭" => [0, 1, 0, 1],
        "╮" => [0, 1, 1, 0],
        "╰" => [1, 0, 0, 1],
        "╯" => [1, 0, 1, 0],

        # ----- Pure heavy --------------------------------------------------
        "━" => [0, 0, 2, 2],
        "┃" => [2, 2, 0, 0],
        "┏" => [0, 2, 0, 2],
        "┓" => [0, 2, 2, 0],
        "┗" => [2, 0, 0, 2],
        "┛" => [2, 0, 2, 0],
        "┣" => [2, 2, 0, 2],
        "┫" => [2, 2, 2, 0],
        "┳" => [0, 2, 2, 2],
        "┻" => [2, 0, 2, 2],
        "╋" => [2, 2, 2, 2],
        "╸" => [0, 0, 2, 0],
        "╹" => [2, 0, 0, 0],
        "╺" => [0, 0, 0, 2],
        "╻" => [0, 2, 0, 0],

        # ----- Mixed light/heavy corners (U+250D-U+251B minus pures) -------
        "┍" => [0, 1, 0, 2], # d light, r heavy
        "┎" => [0, 2, 0, 1], # d heavy, r light
        "┑" => [0, 1, 2, 0], # d light, l heavy
        "┒" => [0, 2, 1, 0], # d heavy, l light
        "┕" => [1, 0, 0, 2], # u light, r heavy
        "┖" => [2, 0, 0, 1], # u heavy, r light
        "┙" => [1, 0, 2, 0], # u light, l heavy
        "┚" => [2, 0, 1, 0], # u heavy, l light

        # ----- Mixed light/heavy left-tees (U+251D-U+2522) -----------------
        "┝" => [1, 1, 0, 2],
        "┞" => [2, 1, 0, 1],
        "┟" => [1, 2, 0, 1],
        "┠" => [2, 2, 0, 1],
        "┡" => [2, 1, 0, 2],
        "┢" => [1, 2, 0, 2],

        # ----- Mixed light/heavy right-tees (U+2525-U+252A) ----------------
        "┥" => [1, 1, 2, 0],
        "┦" => [2, 1, 1, 0],
        "┧" => [1, 2, 1, 0],
        "┨" => [2, 2, 1, 0],
        "┩" => [2, 1, 2, 0],
        "┪" => [1, 2, 2, 0],

        # ----- Mixed light/heavy top-tees (U+252D-U+2532) ------------------
        "┭" => [0, 1, 2, 1],
        "┮" => [0, 1, 1, 2],
        "┯" => [0, 1, 2, 2],
        "┰" => [0, 2, 1, 1],
        "┱" => [0, 2, 2, 1],
        "┲" => [0, 2, 1, 2],

        # ----- Mixed light/heavy bottom-tees (U+2535-U+253A) ---------------
        "┵" => [1, 0, 2, 1],
        "┶" => [1, 0, 1, 2],
        "┷" => [1, 0, 2, 2],
        "┸" => [2, 0, 1, 1],
        "┹" => [2, 0, 2, 1],
        "┺" => [2, 0, 1, 2],

        # ----- Mixed light/heavy crosses (U+253D-U+254A) -------------------
        "┽" => [1, 1, 2, 1],
        "┾" => [1, 1, 1, 2],
        "┿" => [1, 1, 2, 2],
        "╀" => [2, 1, 1, 1],
        "╁" => [1, 2, 1, 1],
        "╂" => [2, 2, 1, 1],
        "╃" => [2, 1, 2, 1],
        "╄" => [2, 1, 1, 2],
        "╅" => [1, 2, 2, 1],
        "╆" => [1, 2, 1, 2],
        "╇" => [2, 1, 2, 2],
        "╈" => [1, 2, 2, 2],
        "╉" => [2, 2, 2, 1],
        "╊" => [2, 2, 1, 2],

        # ----- Pure double -------------------------------------------------
        "═" => [0, 0, 3, 3],
        "║" => [3, 3, 0, 0],
        "╔" => [0, 3, 0, 3],
        "╗" => [0, 3, 3, 0],
        "╚" => [3, 0, 0, 3],
        "╝" => [3, 0, 3, 0],
        "╠" => [3, 3, 0, 3],
        "╣" => [3, 3, 3, 0],
        "╦" => [0, 3, 3, 3],
        "╩" => [3, 0, 3, 3],
        "╬" => [3, 3, 3, 3],

        # ----- Mixed light/double corners (U+2552-U+2559, U+255B-U+255C) ---
        "╒" => [0, 1, 0, 3], # d light, r double
        "╓" => [0, 3, 0, 1], # d double, r light
        "╕" => [0, 1, 3, 0],
        "╖" => [0, 3, 1, 0],
        "╘" => [1, 0, 0, 3],
        "╙" => [3, 0, 0, 1],
        "╛" => [1, 0, 3, 0],
        "╜" => [3, 0, 1, 0],

        # ----- Mixed light/double tees -------------------------------------
        "╞" => [1, 1, 0, 3],
        "╟" => [3, 3, 0, 1],
        "╡" => [1, 1, 3, 0],
        "╢" => [3, 3, 1, 0],
        "╤" => [0, 1, 3, 3],
        "╥" => [0, 3, 1, 1],
        "╧" => [1, 0, 3, 3],
        "╨" => [3, 0, 1, 1],
        "╪" => [1, 1, 3, 3],
        "╫" => [3, 3, 1, 1]
      }.freeze

      # [up, down, left, right] => canonical glyph (non-rounded; light-form
      # preferred where a signature is ambiguous, e.g. the rounded corners).
      GLYPH_FROM_SEGMENTS = SEGMENTS.each_with_object({}) do |(glyph, sig), out|
        # Skip rounded corners — their signatures collide with the non-
        # rounded light corners, which should win as the canonical form.
        next if %w[╭ ╮ ╰ ╯].include?(glyph)

        out[sig] ||= glyph
      end.freeze

      # Merge two glyphs. Returns the union glyph if both are known
      # box-drawing chars and the resulting signature has a Unicode glyph;
      # otherwise the incoming char (new-write-wins).
      def self.merge(existing:, incoming:)
        seg_a = SEGMENTS[existing]
        seg_b = SEGMENTS[incoming]
        return incoming unless seg_a && seg_b

        merged = [seg_a, seg_b].transpose.map(&:max)
        GLYPH_FROM_SEGMENTS[merged] || incoming
      end
    end
  end
end
