# frozen_string_literal: true

module Thaum
  class Text
    include Sigil

    attr_accessor :content

    def initialize(content:, align: :left, wrap: :none)
      @content = content
      @align   = align
      @wrap    = wrap
    end

    def focusable? = false

    def render(canvas:, theme:)
      resolved = content.respond_to?(:call) ? content.call : content
      canvas.text(content: resolved.to_s, fg: theme.fg, align: @align, wrap: @wrap)
    end
  end
end
