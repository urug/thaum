# frozen_string_literal: true

module Thaum
  # Routes an event to the right handler.
  #
  # Two entry points share the same per-event-type case in {#invoke_handler}:
  #
  #   {.from_queue} — events popped off the main run-loop queue. Routes by
  #                   target (modal vs focused Sigil vs App) and returns
  #                   true when the caller should mark the app dirty.
  #   {.from_child} — bubbled events from a Sigil's emit. Routes to the
  #                   handler parent (next outer Octagram, or the App).
  module Dispatch
    module_function

    # Route one event popped off the main queue. Sets the dirty flag for
    # every routed event that does not opt out (TickEvent and unknown
    # objects are the only opt-outs).
    def from_queue(app:, event:)
      if quit_shortcut?(event)
        app.quit
        return
      end

      modal = app.modal_sigil
      auto_dirty =
        case event
        when KeyEvent   then route_key(app: app, modal: modal, event: event)
        when PasteEvent then route_paste(app: app, modal: modal, event: event)
        when MouseEvent then route_mouse(app: app, modal: modal, event: event)
        when ResizeEvent
          Thaum.safe_invoke("App#on_resize") { app.on_resize(event) }
          true
        when TickEvent
          route_tick(app: app, modal: modal, event: event)
          false
        when Event
          Thaum.safe_invoke("App#on_event") { app.on_event(event) }
          true
        else
          false
        end

      app.request_render if auto_dirty
    end

    # Bubbled from a Sigil emit. Caller (App or Octagram) supplies its own
    # safe_invoke label so the stderr trace identifies the handler.
    def invoke_handler(target:, event:, label:)
      Thaum.safe_invoke(label) do
        case event
        when KeyEvent   then target.on_key(event)
        when MouseEvent then target.on_mouse(event)
        when PasteEvent then target.on_paste(event)
        else
          target.on_event(event) if event.is_a?(Event)
        end
      end
    end

    def quit_shortcut?(event)
      event.is_a?(KeyEvent) && event.ctrl? && event.key == "c"
    end

    def route_key(app:, modal:, event:)
      return handle_modal_key(app: app, modal: modal, event: event) if modal

      if (focused = app.focused_sigil)
        Thaum.safe_invoke("#{focused.class}#on_key") { focused.on_key(event) }
      else
        app.handle_tab_cycle(event) if event.key == :tab
        Thaum.safe_invoke("App#on_key") { app.on_key(event) }
      end
      true
    end

    def handle_modal_key(app:, modal:, event:)
      # Plain Escape dismisses the modal — handler never sees it.
      if event.key == :escape && !event.ctrl? && !event.alt? && !event.shift?
        app.hide_modal
        return true
      end
      # Tab / Shift-Tab are eaten while a modal is active.
      return false if event.key == :tab

      Thaum.safe_invoke("#{modal.class}#on_key") { modal.on_key(event) }
      true
    end

    def route_paste(app:, modal:, event:)
      target =
        if modal
          modal
        elsif (focused = app.focused_sigil)
          focused
        else
          app
        end
      label = target.equal?(app) ? "App#on_paste" : "#{target.class}#on_paste"
      Thaum.safe_invoke(label) { target.on_paste(event) }
      true
    end

    def route_mouse(app:, modal:, event:)
      if modal
        dispatch_modal_mouse(modal: modal, event: event, rect: app.modal_rect)
      else
        dispatch_mouse_event(app: app, event: event)
      end
      true
    end

    def route_tick(app:, modal:, event:)
      Thaum.safe_invoke("App#on_tick") { app.on_tick(event) }
      Tree.walk(app) do |node|
        next unless node.is_a?(Sigil) || node.is_a?(Octagram)

        Thaum.safe_invoke("#{node.class}#on_tick") { node.on_tick(event) }
      end
      # Modal Sigil ticks last, after the layout tree (per spec).
      Thaum.safe_invoke("#{modal.class}#on_tick") { modal.on_tick(event) } if modal
    end

    # Hit-test by absolute coords, set canvas-relative x/y on the event, and
    # dispatch to the hit Sigil's on_mouse. If no Sigil is hit, dispatch to
    # the App's on_mouse with abs_x/abs_y unchanged. On :press, transfer
    # focus to the hit Sigil if focusable.
    def dispatch_mouse_event(app:, event:)
      hit = HitTest.hit(app: app, abs_x: event.abs_x, abs_y: event.abs_y)
      if hit
        r = hit.rect
        localized = event.with(x: event.abs_x - r.x, y: event.abs_y - r.y)
        Thaum.safe_invoke("App#focus") { app.focus(hit) } if event.action == :press && hit.focusable?
        Thaum.safe_invoke("#{hit.class}#on_mouse") { hit.on_mouse(localized) }
      else
        Thaum.safe_invoke("App#on_mouse") { app.on_mouse(event) }
      end
    end

    # Route a MouseEvent to the modal Sigil, translating absolute coords to
    # rect-relative. Out-of-bounds clicks are eaten.
    def dispatch_modal_mouse(modal:, event:, rect:)
      return unless rect && HitTest.point_in_rect?(x: event.abs_x, y: event.abs_y, rect: rect)

      local = event.with(x: event.abs_x - rect.x, y: event.abs_y - rect.y)
      Thaum.safe_invoke("#{modal.class}#on_mouse") { modal.on_mouse(local) }
    end
  end
end
