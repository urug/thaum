# frozen_string_literal: true

module Thaum
  # Paints the App + modal tree into a fresh Buffer and hands it to the
  # Renderer. Called once per dirty frame from the run loop.
  module Painter
    module_function

    def paint(app:, renderer:, cols:, rows:)
      theme  = app.theme
      buffer = Rendering::Buffer.new(width: cols, height: rows)
      paint_node(node: app, buffer: buffer, theme: theme)
      paint_modal(app: app, buffer: buffer, theme: theme)
      renderer.render(buffer)
    end

    # Paint the modal Sigil into a Canvas built from its rect. The Buffer
    # silently drops out-of-bounds cells, so an overflowing or fully off-
    # screen modal clips naturally.
    def paint_modal(app:, buffer:, theme:)
      sigil = app.modal_sigil or return
      rect  = app.modal_rect  or return
      return if rect.width <= 0 || rect.height <= 0

      canvas = Rendering::Canvas.new(buffer: buffer, rect: rect)
      Thaum.safe_invoke("#{sigil.class}#render") { sigil.render(canvas: canvas, theme: theme) }
    end

    # Recursive draw walk. Octagrams render their background first (so
    # children draw on top of it). Plain Layout nodes are pass-through.
    # Leaf Sigils render into their own rect.
    def paint_node(node:, buffer:, theme:)
      if node.is_a?(Octagram) && node.rect
        canvas = Rendering::Canvas.new(buffer: buffer, rect: node.rect)
        Thaum.safe_invoke("#{node.class}#render") { node.render(canvas: canvas, theme: theme) }
      end

      (node.subtree_children || []).each do |child|
        if child.is_a?(Sigil)
          r = child.rect or next
          canvas = Rendering::Canvas.new(buffer: buffer, rect: r)
          Thaum.safe_invoke("#{child.class}#render") { child.render(canvas: canvas, theme: theme) }
        elsif child.respond_to?(:subtree_children)
          paint_node(node: child, buffer: buffer, theme: theme)
        end
      end
    end
  end
end
