# frozen_string_literal: true

# Usage: bundle exec ruby examples/counter.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "thaum"

class CounterSigil
  include Thaum::Sigil

  def initialize
    @count = 0
  end

  def on_key(event)
    case event.key
    when :up   then @count += 1
    when :down then @count -= 1
    else emit(event) # Pass unhandled events up to the app
    end
  end

  def render(canvas:, theme:)
    y = canvas.height / 2

    canvas.fill(bg: theme.bg)
    canvas.text(content: "Count: #{@count}", fg: theme.fg, align: :center, y: y)
    canvas.text(content: "↑ / ↓ to change  escape to quit", fg: theme.dim, align: :center, y: y + 2)
  end
end

class CounterApp
  include Thaum::App

  def initialize
    @counter = CounterSigil.new
  end

  def on_key(event)
    quit if event.key == :escape
  end

  def partition
    vertical do
      region(height: :fill) { @counter }
    end
  end
end

Thaum.run(CounterApp.new)
