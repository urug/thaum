# frozen_string_literal: true

module Thaum
  module Concerns
    module Focus
      # --- Focus ---

      def focus(sigil)
        return if @modal_sigil
        return if @focused_sigil.equal?(sigil)
        return if sigil && !focusable_and_mounted?(sigil)

        old = @focused_sigil
        @focused_sigil = sigil
        old&.on_blur
        sigil&.on_focus
        request_render
      end

      def focus_next
        return if @modal_sigil

        leaves = effective_focus_order
        return if leaves.empty?

        idx = @focused_sigil ? (leaves.index(@focused_sigil) || -1) : -1
        focus(leaves[(idx + 1) % leaves.size])
      end

      def focus_prev
        return if @modal_sigil

        leaves = effective_focus_order
        return if leaves.empty?

        idx = @focused_sigil ? (leaves.index(@focused_sigil) || 0) : 0
        focus(leaves[(idx - 1) % leaves.size])
      end

      def focused_sigil = @focused_sigil

      def initial_focus
        (@leaf_sigils || []).find(&:focusable?)
      end

      private

      def focusable_and_mounted?(sigil)
        sigil.focusable? && (@leaf_sigils || []).include?(sigil)
      end
    end
  end
end
