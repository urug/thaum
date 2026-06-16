# frozen_string_literal: true

module Thaum
  # Mouse hit testing for the layout tree and modals.
  module HitTest
    module_function

    # Walk every leaf Sigil with an allocated rect, return the LAST one
    # whose rect contains (abs_x, abs_y). Last-in-render-order wins on
    # overlap, matching the draw walk in Painter.
    def hit(app:, abs_x:, abs_y:)
      hit = nil
      Tree.walk(app) do |node|
        next unless node.is_a?(Sigil)

        rect = node.rect or next
        next unless point_in_rect?(x: abs_x, y: abs_y, rect: rect)

        hit = node
      end
      hit
    end

    def point_in_rect?(x:, y:, rect:)
      x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height
    end
  end
end
