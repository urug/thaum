# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- `InputReader#stop` no longer blocks ~1s on quit; the reader thread is interrupted instead of left to time out.

### Changed

- Moved `Thaum::Concerns::Layout` back to `Thaum::Layout`. Includes in `App`, `Octagram`, and downstream code should reference the top-level module.
