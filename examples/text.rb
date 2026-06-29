# frozen_string_literal: true

# Usage: bundle exec ruby examples/text.rb
#
# Demonstrates Thaum::Text — the configurable drop-in Sigil for static
# content. Each row shows a different (align, wrap) combination.
# Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

LONG = "Thaum is a Ruby TUI framework. Sigils render and handle events; " \
       "Layouts partition space. This sentence is long enough to demonstrate " \
       "word-wrap inside a bounded region."

class Bar
  include Thaum::Sigil

  def initialize(label:, semantic_fg: nil)
    @label = label
    @semantic_fg = semantic_fg
  end

  def focusable? = false

  def render(canvas:, theme:)
    canvas.fill(bg: theme.bar_bg)
    fg = @semantic_fg ? theme.send(@semantic_fg) : theme.muted_fg
    canvas.text(content: " #{@label}", fg: fg)
  end
end

class SemanticText
  include Thaum::Sigil

  def initialize(label:, semantic_color:)
    @label = label
    @semantic_color = semantic_color
  end

  def focusable? = false

  def render(canvas:, theme:)
    fg = theme.send(@semantic_color)
    content = "#{@label}: #{@semantic_color}".ljust(60)

    canvas.fill(bg: theme.bg)
    canvas.text(content:, fg:)
  end
end

class TextApp
  include Thaum::App

  def initialize
    @bar_align = Bar.new(label: "alignment — left / center / right")
    @left      = Thaum::Text.new(content: "left-aligned",   align: :left)
    @center    = Thaum::Text.new(content: "center-aligned", align: :center)
    @right     = Thaum::Text.new(content: "right-aligned",  align: :right)

    @bar_wrap  = Bar.new(label: "wrap — :word (4-line box) vs :none (truncated)")
    @wrapped   = Thaum::Text.new(content: LONG, align: :left, wrap: :word)
    @no_wrap   = Thaum::Text.new(content: LONG, align: :left, wrap: :none)

    @bar_semantic = Bar.new(label: "semantic color tokens", semantic_fg: :accent)
    @success   = SemanticText.new(label: "✓ Success", semantic_color: :success_fg)
    @warning   = SemanticText.new(label: "⚠ Warning", semantic_color: :warning_fg)
    @error     = SemanticText.new(label: "✗ Error", semantic_color: :error_fg)
    @info      = SemanticText.new(label: "ℹ Info", semantic_color: :info_fg)
    @muted     = SemanticText.new(label: "◻ Muted", semantic_color: :muted_fg)
    @disabled  = SemanticText.new(label: "⊘ Disabled", semantic_color: :disabled_fg)

    @hint      = Bar.new(label: "esc to quit")
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical do
      region(height: 1) { @bar_align }
      region(height: 1) { @left }
      region(height: 1) { @center }
      region(height: 1) { @right }
      region(height: 1) { @bar_wrap }
      region(height: 4) { @wrapped }
      region(height: 1) { @no_wrap }
      region(height: 1) { @bar_semantic }
      region(height: 1) { @success }
      region(height: 1) { @warning }
      region(height: 1) { @error }
      region(height: 1) { @info }
      region(height: 1) { @muted }
      region(height: 1) { @disabled }
      region(height: :fill) { @hint }
    end
  end
end

TextApp.run
