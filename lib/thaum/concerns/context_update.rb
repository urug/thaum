# frozen_string_literal: true

module Thaum
  module Concerns
    module ContextUpdate
      # --- Context ---

      def update_context(hash)
        cloned = deep_freeze(hash.dup)
        @context = cloned
        @in_on_update = true
        begin
          Tree.walk(self) do |node|
            next unless node.is_a?(Sigil) || node.is_a?(Octagram)

            node.on_update(cloned)
          end
          # Modal Sigil receives on_update last, after the layout tree.
          @modal_sigil&.on_update(cloned)
        ensure
          @in_on_update = false
        end
        request_render
      end

      private

      def deep_freeze(obj)
        case obj
        when Hash
          obj.transform_values! { |v| deep_freeze(v) }.freeze
        when Array
          obj.map! { |v| deep_freeze(v) }.freeze
        else
          obj
        end
      end
    end
  end
end
