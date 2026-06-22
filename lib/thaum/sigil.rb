# frozen_string_literal: true

module Thaum
  module Sigil
    attr_accessor :rect, :thaum_app, :handler_parent

    # The safe-nav `&.` makes `focused_sigil` nil when no app is set; nil.equal?(self) is false.
    def focused?    = @thaum_app&.focused_sigil.equal?(self)
    def focusable?  = true
    def request_render = @thaum_app&.request_render

    def emit(event)
      app = @thaum_app or return
      raise Thaum::EmitFromUpdateError, "emit called from on_update" if app.in_on_update

      if event.is_a?(Thaum::TickEvent) || event.is_a?(Thaum::ResizeEvent)
        Thaum.warn_internal("dropping #{event.class} from #{self.class}: " \
                            "framework-internal events cannot be emitted from Sigils or Actions",
                            level: :warn)
        return
      end

      (@handler_parent || app).dispatch_from_child(event)
    end

    # Rendering — override in subclass
    def render(canvas:, theme:); end

    # Terminal event handlers — defaults propagate via emit
    def on_key(event)   = emit(event)
    def on_mouse(event) = emit(event)
    def on_paste(event) = emit(event)

    # Lifecycle — override for side effects
    def on_mount;             end
    def on_unmount;           end
    def on_focus;             end
    def on_blur;              end
    def on_update(context);   end
    def on_tick(event);       end
  end
end
