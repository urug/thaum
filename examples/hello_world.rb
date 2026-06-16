# frozen_string_literal: true

# Usage: bundle exec ruby examples/hello_world.rb
# A minimal "Hello World" app. Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "thaum"

class HelloWorldApp
  include Thaum::App

  def on_key(event)
    quit if event.key == :escape
  end

  def initialize
    @greeting = Thaum::Text.new(content: "Hello World!", align: :center)
  end

  def partition
    vertical do
      region(height: :fill) { @greeting }
    end
  end
end

Thaum.run(HelloWorldApp.new)
