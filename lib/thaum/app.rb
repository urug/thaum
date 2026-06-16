# frozen_string_literal: true

module Thaum
  module App
    include Concerns::Layout
    include Concerns::Focus
    include Concerns::ContextUpdate
    include Concerns::Modal
    include Concerns::TabNavigation

    attr_reader :in_on_update, :modal_sigil, :modal_rect

    # --- Quit ---

    def quit = (@quit_requested = true)
    def quit? = @quit_requested

    # --- Render dirty flag ---

    def request_render = (@dirty = true)
    def dirty? = @dirty
    def clear_dirty = (@dirty = false)

    # --- Mount wiring ---

    def wire_sigils
      (@leaf_sigils || []).each { |s| s.thaum_app = self }
      wire_handler_parents(handler_parent: self, app: self)
    end

    def thaum_app_ref = self

    # Used by the run loop to seed the initially-focused Sigil before
    # entering the main loop. Bypasses Focus#focus's mount check because
    # the mount pass has already run.
    def set_initial_focus(sigil) = (@focused_sigil = sigil)

    # --- Dispatch from child (synchronous, main thread) ---

    # A child here is either the focused Sigil (when it emits) or the
    # outermost Octagram (which propagates from its own children). Tab
    # cycling is intercepted before App#on_key so handlers see :tab with
    # focus already updated.
    def dispatch_from_child(event)
      # When a modal is active, bubbled Tab/Shift-Tab is eaten. Other
      # bubbled events still reach App handlers — emit from the modal Sigil
      # can therefore reach App#on_event so apps can react to modal events.
      return if @modal_sigil && event.is_a?(KeyEvent) && event.key == :tab

      handle_tab_cycle(event) if event.is_a?(KeyEvent) && event.key == :tab

      Dispatch.invoke_handler(target: self, event:, label: "App##{handler_name_for(event)}")
    end
    alias dispatch_from_sigil dispatch_from_child

    # --- Theme (override to choose a non-default theme for this app) ---

    def theme = Themes::DEFAULT

    # --- Default App handlers (no-ops — App is top of dispatch chain) ---

    def on_key(event);      end
    def on_mouse(event);    end
    def on_paste(event);    end
    def on_resize(event);   end
    def on_tick(event);     end
    def on_mount;           end
    def on_unmount;         end

    def on_event(event)
      warn "[Thaum] unhandled event: #{event.class} #{event.inspect}"
    end

    private

    def focusable_leaves = (@leaf_sigils || []).select(&:focusable?)

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
