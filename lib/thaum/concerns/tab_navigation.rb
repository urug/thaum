# frozen_string_literal: true

module Thaum
  module Concerns
    module TabNavigation
      # Called by the framework before App#on_key sees a bubbled :tab.
      # Shift-Tab moves focus backward; plain Tab moves forward. The App's
      # on_key then runs with focus already updated (see spec — Tab pipeline).
      #
      # When the focused Sigil is inside an Octagram, cycling is SCOPED to
      # that Octagram's focusable units first. Reaching the boundary bubbles
      # to the parent scope (next outer Octagram, or the App), which treats
      # the inner Octagram as a single unit. The App falls back to the flat
      # focus_next/focus_prev path only when no Octagram boundaries are
      # involved — preserving existing behavior for Octagram-free apps.
      def handle_tab_cycle(event)
        direction = event.shift? ? :prev : :next
        sigil = @focused_sigil

        if sigil && inside_octagram?(sigil)
          target = scoped_tab_target(sigil: sigil, direction: direction)
          focus(target) if target
        else
          direction == :next ? focus_next : focus_prev
        end
      end

      private

      # True when the Sigil's handler chain crosses at least one Octagram.
      def inside_octagram?(sigil)
        parent = sigil.handler_parent
        while parent
          return true if parent.is_a?(Octagram)

          parent = parent.respond_to?(:handler_parent) ? parent.handler_parent : nil
        end
        false
      end

      # Walk scopes from innermost outward. At each scope, find the unit
      # representing where we currently are (the sigil itself, or the inner
      # Octagram unit we just bubbled out of). Step one unit in `direction`.
      # If stepping would wrap past the scope boundary, bubble to the parent
      # scope. App scope wraps within itself (the final fallback).
      def scoped_tab_target(sigil:, direction:)
        scope         = innermost_octagram_for(sigil)
        current_unit  = sigil

        loop do
          units = scope.focus_scope_units
          idx   = units.index(current_unit)
          # Defensive: if current_unit isn't in this scope's units, treat as
          # entering from before the first (next) or after the last (prev).
          return resolve_unit(unit: units.first, direction: direction) if idx.nil? && !units.empty?

          step      = direction == :next ? 1 : -1
          new_idx   = idx + step
          in_bounds = new_idx >= 0 && new_idx < units.size

          if in_bounds
            return resolve_unit(unit: units[new_idx], direction: direction)
          elsif scope.equal?(self)
            # At App scope — wrap.
            wrapped = direction == :next ? units.first : units.last
            return resolve_unit(unit: wrapped, direction: direction)
          else
            # Bubble to parent scope; the Octagram itself becomes the unit.
            current_unit = scope
            scope        = innermost_octagram_for(scope) || self
          end
        end
      end

      # Drill into a unit to get the focusable Sigil to focus. Plain Sigil →
      # itself. Octagram → first (or last) focusable leaf.
      def resolve_unit(unit:, direction:)
        return unit if unit.is_a?(Sigil)
        return nil  unless unit.respond_to?(:first_focusable_leaf)

        direction == :next ? unit.first_focusable_leaf : unit.last_focusable_leaf
      end

      # Innermost enclosing Octagram in the handler chain, or nil if none
      # (focused sigil is directly under App with no Octagram between).
      def innermost_octagram_for(node)
        parent = node.handler_parent
        while parent
          return parent if parent.is_a?(Octagram)

          parent = parent.respond_to?(:handler_parent) ? parent.handler_parent : nil
        end
        nil
      end
    end
  end
end
