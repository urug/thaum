# frozen_string_literal: true

module Thaum
  KeyEvent = Event.define(:key, :ctrl, :alt, :shift) do
    def initialize(key:, ctrl: false, alt: false, shift: false)
      super
    end

    def ctrl?  = ctrl
    def alt?   = alt
    def shift? = shift
  end
end
