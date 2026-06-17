# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- `InputReader#stop` no longer blocks ~1s on quit; the reader thread is interrupted instead of left to time out.
- Escape sequences split across read boundaries are now coalesced instead of being mis-parsed as a stray Escape plus garbage keys. `InputReader#read_chunk` now extends the read whenever a chunk ends mid-sequence (CSI/SS3/SGR-mouse or a bare ESC), bounded by a timeout and an extend cap.
- Centered/right-aligned wrapped text drawn at an x-offset is now positioned against the offset content area instead of the full canvas width.

### Added

- Honor the `NO_COLOR` environment variable — when set and non-empty, color output is disabled.

### Changed

- Moved `Thaum::Concerns::Layout` back to `Thaum::Layout`. Includes in `App`, `Octagram`, and downstream code should reference the top-level module.
- `Thaum::Action` raises a clear `Thaum::Error` when a background method is called outside a running app, instead of a `NoMethodError` on nil.
