# frozen_string_literal: true

module Thaum
  module Concerns
    module Modal
      # --- Modal ---

      # Show a modal Sigil as an overlay above the layout tree. width/height
      # are required; x/y are optional terminal-absolute coords — when nil
      # the modal is centered on the current terminal size. Calling show_modal
      # while a modal is already active fires on_blur + on_unmount on the
      # outgoing modal and replaces it. The previously-focused Sigil (from
      # before any modal was shown) is preserved so hide_modal can restore it.
      def show_modal(sigil:, width:, height:, x: nil, y: nil)
        replacing = !@modal_sigil.nil?
        centered  = x.nil? && y.nil?

        if replacing
          Thaum.safe_invoke("#{@modal_sigil.class}#on_blur")    { @modal_sigil.on_blur }
          Thaum.safe_invoke("#{@modal_sigil.class}#on_unmount") { @modal_sigil.on_unmount }
          @modal_sigil.thaum_app      = nil
          @modal_sigil.handler_parent = nil
          @modal_sigil.rect = nil
        elsif @focused_sigil
          # First modal — save the underlying focused Sigil and fire its on_blur.
          @previous_focus = @focused_sigil
          Thaum.safe_invoke("#{@focused_sigil.class}#on_blur") { @focused_sigil.on_blur }
          @focused_sigil = nil
        end

        rect = compute_modal_rect(width: width, height: height, x: x, y: y)

        @modal_sigil      = sigil
        @modal_rect       = rect
        @modal_centered   = centered
        @modal_decl_w     = width
        @modal_decl_h     = height
        sigil.thaum_app      = self
        sigil.handler_parent = self
        sigil.rect = rect

        Thaum.safe_invoke("#{sigil.class}#on_mount") { sigil.on_mount }
        Thaum.safe_invoke("#{sigil.class}#on_focus") { sigil.on_focus }

        request_render
        sigil
      end

      def hide_modal
        sigil = @modal_sigil
        return unless sigil

        Thaum.safe_invoke("#{sigil.class}#on_blur")    { sigil.on_blur }
        Thaum.safe_invoke("#{sigil.class}#on_unmount") { sigil.on_unmount }

        @modal_sigil      = nil
        @modal_rect       = nil
        @modal_centered   = false
        @modal_decl_w     = nil
        @modal_decl_h     = nil
        sigil.thaum_app      = nil
        sigil.handler_parent = nil
        sigil.rect = nil

        restored = @previous_focus
        @previous_focus = nil
        if restored && focusable_and_mounted?(restored)
          @focused_sigil = restored
          Thaum.safe_invoke("#{restored.class}#on_focus") { restored.on_focus }
        end

        request_render
        nil
      end

      def modal_active? = !@modal_sigil.nil?

      # Called by the framework on ResizeEvent after the layout repartitions.
      # Re-centers a default-centered modal on the new terminal dimensions.
      # Modals with explicit x/y stay put.
      def recompute_modal_rect
        return unless @modal_sigil && @modal_centered

        @modal_rect = compute_modal_rect(width: @modal_decl_w, height: @modal_decl_h, x: nil, y: nil)
        @modal_sigil.rect = @modal_rect
      end

      private

      # Compute the modal's terminal-absolute rect from declared size + optional
      # x/y. When x/y are nil, centers on the App's current rect (set by
      # run_partition to the terminal's dimensions). Overflow is allowed —
      # the Buffer drops out-of-bounds cells at paint time.
      def compute_modal_rect(width:, height:, x:, y:)
        app_rect = @rect || Rect.new(x: 0, y: 0, width: 0, height: 0)
        cx = x.nil? ? app_rect.x + ((app_rect.width  - width)  / 2) : x
        cy = y.nil? ? app_rect.y + ((app_rect.height - height) / 2) : y
        Rect.new(x: cx, y: cy, width: width, height: height)
      end
    end
  end
end
