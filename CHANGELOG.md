# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Dev log console — `Thaum.log` writes a debug side channel to a file (`Thaum.run(app, log: path)`), so you can log without corrupting the TUI (stdout is the UI). Logger-style API (`debug`/`info`/`warn`/`error`, lazy block form, exception formatting); off by default; truncates on open. While a log is active, framework-internal warnings route to it instead of stderr — `safe_invoke` handler exceptions at ERROR, emit-guard warnings at WARN. Companion examples `log_reader.rb` (tails and colorizes the file live) and `log_generator.rb`. See `docs/logging.md`.

## [0.2.1] - 2026-06-17

### Fixed

- `InputReader#stop` no longer blocks ~1s on quit; the reader thread is interrupted instead of left to time out.
- Escape sequences split across read boundaries are now coalesced instead of being mis-parsed as a stray Escape plus garbage keys. `InputReader#read_chunk` now extends the read whenever a chunk ends mid-sequence (CSI/SS3/SGR-mouse or a bare ESC), bounded by a timeout and an extend cap.
- Centered/right-aligned wrapped text drawn at an x-offset is now positioned against the offset content area instead of the full canvas width.

### Added

- Honor the `NO_COLOR` environment variable — when set and non-empty, color output is disabled.

### Changed

- Moved `Thaum::Concerns::Layout` back to `Thaum::Layout`. Includes in `App`, `Octagram`, and downstream code should reference the top-level module.
- `Thaum::Action` raises a clear `Thaum::Error` when a background method is called outside a running app, instead of a `NoMethodError` on nil.
