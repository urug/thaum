```
╭─────────────────────────────────────────────────────╮
│  ▒▒▒▒▒▒▒▒╗ ▒▒╗  ▒▒╗  ▒▒▒▒▒╗  ▒▒╗   ▒▒╗ ▒▒▒╗   ▒▒▒╗  │ 
│  ╚══▒▒╔══╝ ▒▒║  ▒▒║ ▒▒╔══▒▒╗ ▒▒║   ▒▒║ ▒▒▒▒╗ ▒▒▒▒║  │
│     ▒▒║    ▒▒▒▒▒▒▒║ ▒▒▒▒▒▒▒║ ▒▒║   ▒▒║ ▒▒╔▒▒▒▒╔▒▒║  │
│     ▒▒║    ▒▒╔══▒▒║ ▒▒╔══▒▒║ ▒▒║   ▒▒║ ▒▒║╚▒▒╔╝▒▒║  │
│     ▒▒║    ▒▒║  ▒▒║ ▒▒║  ▒▒║ ╚▒▒▒▒▒▒╔╝ ▒▒║ ╚═╝ ▒▒║  │
│     ╚═╝    ╚═╝  ╚═╝ ╚═╝  ╚═╝  ╚═════╝  ╚═╝     ╚═╝  │ 
╰─────────────────────────────────────────────────────╯
```
> A Thaum is the basic unit of magical strength. It has been universally established as the amount of magic needed to create one small white pigeon or three normal-sized billiard balls. [*](#Footnotes)
>
> — Terry Pratchett

Compose full-screen TUI apps from a few parts:

- **App** — top-level container that owns layout, focus, and event handling
- **Layout** — vertical/horizontal split DSL (`region(height: 3)`, `region(width: :fill)`, …)
- **Sigil** — focusable, renderable leaf component (`Text`, `TextInput`, `Select`, `Button`, `ScrollView`, `Table`, `Spinner`, `ProgressBar`, `Checkbox`, `Tabs`)
- **Octagram** — composite that contains sigils and presents itself as a distributable component

Features:

- Buffer-diffing renderer with synchronized output (`\e[?2026h`)
- Truecolor with automatic degradation to 256 / 16 / no-color based on `$COLORTERM` and `$TERM`
- Themes (8 built-in palettes — Solarized, Gruvbox, Catppuccin, …)
- Event dispatch: keys, paste, ticks, resize, suspend/resume
- Focus with Tab/Shift-Tab cycling and overridable `focus_order`
- Background work via `Thaum::Action` (concurrent-ruby thread pool)
- Box-drawing junction merging — adjacent borders resolve to the correct corner/tee glyph automatically, across light/heavy/double weights
- Snapshot testing via `thaum/minitest`

## Installation

```bash
bundle add thaum
```

Or:

```bash
gem install thaum
```

Requires Ruby 3.2 or newer.

## Usage

The `Hello World` example:

```ruby
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

```

## Examples

The `examples/` directory has a runnable demo for every shipped sigil plus a few composed apps:

```bash
bundle exec ruby examples/counter.rb         # minimal app
bundle exec ruby examples/picker.rb          # filter-as-you-type list selector
bundle exec ruby examples/todo.rb            # TextInput + Select + Button
bundle exec ruby examples/stopwatch.rb       # on_tick driven
bundle exec ruby examples/theme_picker.rb    # cycle the built-in themes
bundle exec ruby examples/layout_demo.rb     # nested Layout DSL + border junctions
bundle exec ruby examples/octagram_picker.rb # picker packaged as an Octagram
```

Per-sigil demos: `text.rb`, `select.rb`, `checkbox.rb`, `tabs.rb`, `spinner.rb`, `progress_bar.rb`, `scroll_view.rb`, `table.rb`.

## Snapshot testing

```ruby
require "thaum/minitest"

class MySigilTest < Minitest::Test
  def test_renders_greeting
    buffer = Thaum::Rendering::Buffer.new(width: 20, height: 3)
    canvas = Thaum::Rendering::Canvas.new(buffer: buffer, rect: Thaum::Rect.new(x: 0, y: 0, width: 20, height: 3))
    MySigil.new.render(canvas: canvas, theme: Thaum::Themes::DEFAULT)
    assert_snapshot(buffer, "my_sigil/greeting")
  end
end
```

First run writes `test/snapshots/my_sigil/greeting.txt` (or `.ans` if the output contains ANSI styling) and passes with a warning. Re-run with `UPDATE_SNAPSHOTS=1` to refresh existing snapshots.

## Development

```bash
bin/setup       # bundle install
rake test       # run the test suite (Minitest)
rake rubocop    # lint
rake            # both
bin/console     # IRB with thaum required
```

To install locally: `bundle exec rake install`. To cut a release: bump `lib/thaum/version.rb`, then `bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome at https://github.com/urug/thaum.

## License

MIT. See [LICENSE.txt](LICENSE.txt).

### Footnotes

\* Also, a terminal window
