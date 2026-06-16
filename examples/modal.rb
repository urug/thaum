# frozen_string_literal: true

# Usage: bundle exec ruby examples/modal.rb
#
# Press "m" to open a modal. Inside the modal, press Escape (framework-
# intercepted) or "y"/"n" to dismiss. Outside the modal, Escape quits.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class Background
  include Thaum::Sigil

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bg)
    canvas.text(content: "Press m to open a modal, esc to quit.", fg: theme.fg, align: :center, y: canvas.height / 2)
    canvas.text(content: "(Modal can be Escape-dismissed.)", fg: theme.dim, align: :center, y: (canvas.height / 2) + 2)
  end
end

class Confirm
  include Thaum::Sigil

  DismissedEvent = Thaum::Event.define(:choice)

  def render(canvas:, theme:)
    inner = canvas.border(style: :rounded, fg: theme.warning_fg, bg: theme.bg)
    inner.fill(bg: theme.bg)
    inner.text(content: "Are you sure?", fg: theme.warning_fg, align: :center, y: 1)
    inner.text(content: "[y]es   [n]o   Esc cancels", fg: theme.muted_fg, align: :center, y: 3)
  end

  def on_key(event)
    case event.key
    when "y", "n" then emit(DismissedEvent.new(choice: event.key))
    else emit(event)
    end
  end
end

class ModalApp
  include Thaum::App

  def initialize
    @choice_display = Thaum::Text.new(content: "Modal choice: none", align: :center)
    @background = Background.new
  end

  def partition
    vertical do
      region(height: 1) { @choice_display }
      region(height: :fill) { @background }
    end
  end

  def on_key(event)
    case event.key
    when :escape then quit
    when "m" then show_modal(sigil: Confirm.new, width: 36, height: 7)
    end
  end

  def on_event(event)
    case event
    when Confirm::DismissedEvent
      @choice_display.content = "Modal choice: #{event.choice}"
      hide_modal
    else
      super
    end
  end
end

Thaum.run(ModalApp.new)
