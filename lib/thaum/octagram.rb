# frozen_string_literal: true

module Thaum
  # A composite container — a distributable component that owns both
  # layout (Layout DSL) and behavior (Sigil-like handlers). Sits between
  # its child Sigils and the App in the dispatch chain: when a focused
  # child Sigil emits, the innermost enclosing Octagram's handler runs
  # first, and propagates upward only if it calls emit.
  #
  # See DECISIONS.md (2026-06-02) for the naming rationale.
  module Octagram
    include Layout

    attr_accessor :thaum_app, :handler_parent

    # Marker so the framework's tree-walks can distinguish Octagrams
    # from plain Layouts (which don't participate in event dispatch).
    def octagram? = true

    # Optional background — drawn before the Octagram's child sigils.
    # Override to paint a frame, border, or fill behind the children.
    def render(canvas:, theme:); end

    # Override to inset the rect the Octagram's children partition into,
    # so the render hook above is not overwritten by child rendering.
    # Return a Hash with any of :top, :bottom, :left, :right keys (each
    # an Integer; missing keys default to 0). For a 1-cell border on all
    # sides, return { top: 1, bottom: 1, left: 1, right: 1 }.
    def partition_inset = nil

    # Handlers — same shape as Sigil. Defaults propagate to the handler
    # parent (the next outer Octagram, or the App).
    def on_key(event)   = emit(event)
    def on_mouse(event) = emit(event)
    def on_paste(event) = emit(event)
    def on_event(event) = emit(event)

    # Lifecycle — overridable.
    def on_mount;             end
    def on_unmount;           end
    def on_update(context);   end
    def on_tick(event);       end

    # Propagate an event to this Octagram's handler parent. Mirrors
    # Sigil#emit: drops framework-internal events and respects the
    # emit-from-on_update guard.
    def emit(event)
      app = @thaum_app or return
      raise Thaum::EmitFromUpdateError, "emit called from on_update" if app.in_on_update

      if event.is_a?(Thaum::TickEvent) || event.is_a?(Thaum::ResizeEvent)
        warn "[Thaum] dropping #{event.class} from #{self.class}: " \
             "framework-internal events cannot be emitted from Sigils or Actions"
        return
      end

      (@handler_parent || app).dispatch_from_child(event)
    end

    # Called by a child Sigil (or nested Octagram) when it emits.
    def dispatch_from_child(event)
      Dispatch.invoke_handler(target: self, event: event, label: "#{self.class}##{handler_name_for(event)}")
    end

    private

    def handler_name_for(event)
      case event
      when KeyEvent   then "on_key"
      when MouseEvent then "on_mouse"
      when PasteEvent then "on_paste"
      else                 "on_event"
      end
    end
  end
end
