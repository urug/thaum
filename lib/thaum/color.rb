# frozen_string_literal: true

module Thaum
  # Capability detection and color-to-escape mapping with degradation
  # (truecolor → 256 → 16 → none).
  module Color
    HEX_COLOR_PATTERN = /\A#[0-9a-fA-F]{6}\z/

    # 16 ANSI color RGB approximations (VGA palette) and their SGR codes
    # for foreground. Background = fg + 10. Bright = (90 or 100) base.
    ANSI_16 = {
      black: { rgb: [0, 0, 0], fg: 30, bg: 40 },
      red: { rgb: [170, 0, 0], fg: 31, bg: 41 },
      green: { rgb: [0, 170, 0], fg: 32, bg: 42 },
      yellow: { rgb: [170, 85, 0], fg: 33, bg: 43 },
      blue: { rgb: [0,   0, 170], fg: 34, bg: 44 },
      magenta: { rgb: [170, 0, 170], fg: 35, bg: 45 },
      cyan: { rgb: [0, 170, 170], fg: 36, bg: 46 },
      white: { rgb: [170, 170, 170], fg: 37, bg: 47 },
      bright_black: { rgb: [85, 85, 85], fg: 90, bg: 100 },
      bright_red: { rgb: [255, 85, 85], fg: 91, bg: 101 },
      bright_green: { rgb: [85, 255, 85], fg: 92, bg: 102 },
      bright_yellow: { rgb: [255, 255, 85], fg: 93, bg: 103 },
      bright_blue: { rgb: [85, 85, 255], fg: 94, bg: 104 },
      bright_magenta: { rgb: [255, 85, 255], fg: 95, bg: 105 },
      bright_cyan: { rgb: [85, 255, 255], fg: 96, bg: 106 },
      bright_white: { rgb: [255, 255, 255], fg: 97, bg: 107 }
    }.freeze

    def self.detect(env)
      colorterm = env["COLORTERM"]
      term      = env["TERM"]
      return :truecolor if %w[truecolor 24bit].include?(colorterm)
      return :none      if term.nil? || term.empty? || term == "dumb"
      return :"256"     if term.include?("256color")

      :ansi
    end

    def self.to_escape(color, capability:, base:)
      return "" if capability == :none
      return "" if color.nil?

      if color.is_a?(Array)
        hex, fallback = color
        return capability == :ansi ? to_escape(fallback, capability:, base:) : to_escape(hex, capability:, base:)
      end

      case color
      when Symbol then named_escape(name: color, base: base)
      when String then hex_escape(hex: color, capability: capability, base: base)
      else ""
      end
    end

    def self.named_escape(name:, base:)
      info = ANSI_16[name]
      return "\e[#{base == 38 ? 39 : 49}m" if name == :default
      return "" unless info

      code = base == 38 ? info[:fg] : info[:bg]
      "\e[#{code}m"
    end

    def self.hex_escape(hex:, capability:, base:)
      return "" unless hex.match?(HEX_COLOR_PATTERN)

      r = hex[1..2].to_i(16)
      g = hex[3..4].to_i(16)
      b = hex[5..6].to_i(16)

      case capability
      when :truecolor then "\e[#{base};2;#{r};#{g};#{b}m"
      when :"256"     then "\e[#{base};5;#{hex_to_256(r: r, g: g, b: b)}m"
      when :ansi      then named_escape(name: hex_to_ansi(r: r, g: g, b: b), base: base)
      else ""
      end
    end

    def self.hex_to_256(r:, g:, b:) # rubocop:disable Naming/VariableNumber
      # 6x6x6 color cube: 16 + 36*r6 + 6*g6 + b6
      r6 = (r * 5.0 / 255).round
      g6 = (g * 5.0 / 255).round
      b6 = (b * 5.0 / 255).round
      16 + (36 * r6) + (6 * g6) + b6
    end

    def self.hex_to_ansi(r:, g:, b:)
      ANSI_16.min_by do |_name, info|
        ar, ag, ab = info[:rgb]
        ((r - ar)**2) + ((g - ag)**2) + ((b - ab)**2)
      end.first
    end

    private_class_method :named_escape, :hex_escape, :hex_to_256, :hex_to_ansi # rubocop:disable Naming/VariableNumber
  end
end
