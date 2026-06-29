# frozen_string_literal: true

# Usage: bundle exec ruby examples/hello_world.rb
# A minimal "Hello World" app using Thaum.app in place of a named class.
# Press esc to quit.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "thaum"

Thaum.app do
  def partition
    vertical do
      region(height: :fill) { Thaum::Text.new(content: "Hello World!", align: :center) }
    end
  end

  def on_key(event)
    quit if event.key == :escape
  end
end
