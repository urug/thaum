# Dev log console

In a Thaum app stdout *is* the UI, so you can't `puts`-debug — the output paints
over the alt-screen the renderer owns. `Thaum.log` is a side channel: pass a path
to `Thaum.run` and log lines go to that file instead, where a companion process
can tail them live.

## `Thaum.log`

```ruby
Thaum.run(app, log: "thaum.log")   # a path enables logging; nil (default) is off

Thaum.log.debug("cursor=#{n}")
Thaum.log.info("mounted Picker")
Thaum.log.warn("slow frame 48ms")
Thaum.log.error(exception)         # class + message + backtrace
Thaum.log.debug { expensive_dump } # block only built when logging is active
```

`Thaum.log` returns a logger; severity methods return `nil`. The block form is for
expensive messages — when no sink is active the block is never invoked. Passing an
`Exception` formats its class, message, and backtrace.

Behavior:

- **Off by default.** `log:` defaults to `nil`; every `Thaum.log` call is then a
  cheap no-op. An explicit path string is required to enable it — no env var, no
  default path.
- **Truncate on open.** The file starts fresh each run, so a tailing reader that
  sees the file shrink knows the app restarted. The reader detects this when the
  file is smaller than its read offset; if a restarted app writes *more* bytes
  than the previous offset before the reader's next tick, the shrink is missed
  and parsing resumes mid-file until the next restart. Inherent to tailing a
  truncated file; the 100ms tick makes it unlikely in practice.
- **Plain-text lines.** Format is `HH:MM:SS.mmm LEVEL  message` — readable with
  `tail -f` and no companion at all; the reader example just colorizes it.
- **Internal warnings route here too.** While a sink is active, the framework's own
  warnings — handler exceptions caught by `Thaum.safe_invoke` (ERROR) and
  emit-guard warnings (WARN) — go to the log file instead of corrupting the screen
  via stderr. With no sink, stderr behavior is unchanged.

## The console examples

Two examples form a working console. Run them in separate terminals, in any order,
sharing a path (both default to `thaum.log` in the working dir):

```bash
bundle exec ruby examples/log_reader.rb thaum.log     # the live viewer (a Thaum TUI)
bundle exec ruby examples/log_generator.rb thaum.log  # emits log lines on keypress/tick
```

The reader (`examples/log_reader.rb`) is a Thaum app with a bespoke `LogView` sigil
defined inline. It tails the file on each tick, parses lines, and:

- colorizes by level — debug dim, info default, warn yellow, error red;
- follows the tail by default (any scroll key drops follow; `End` restores it);
- cycles a minimum display level with `f`;
- filters rows by substring with `/`.

The generator (`examples/log_generator.rb`) emits a line per keypress (`d`/`i`/`w`/`e`)
or every tick (`space` toggles), and `x` deliberately raises inside a handler to
show `safe_invoke`'s exception routing land in the log at ERROR.

## Architecture

`Thaum.log`, the sink, and the warning routing are the framework feature; the
console viewer ships as an example (dogfooding the framework), not an executable.

- `Thaum::Log::Sink` — the `open` / `write(line)` / `close` contract.
- `Thaum::Log::FileSink` — the only implementation today: truncate-on-open,
  `sync = true`, mutex-guarded writes (the input-reader thread, tick timer, and
  action pool all log concurrently). A future `SocketSink` can drop in behind the
  same contract without changing the `Thaum.log` API.
- `Thaum::Log::Logger` — what `Thaum.log` returns. Reads the active sink per call,
  so it tracks the per-run sink; formats and hands one line per record to the sink.

The run loop opens the sink before terminal setup and closes it last in `ensure`,
so the sink is live across all of the framework's `safe_invoke`-wrapped work
(mount, dispatch, render, teardown).

## Out of scope (today)

- Socket transport (`SocketSink`) — the interface is ready for it.
- Promoting the reader example to a shipped `exe/` executable.
- App-side level filtering and log rotation (the reader filters what it *displays*).
- Nested or concurrent `Thaum.run` calls in one process. The active sink
  (`Thaum::Log.sink`) and `Thaum.log` are process-global, so a second run would
  clobber the first's sink. One app per process is assumed, matching the TUI
  model (one app owns the terminal).
