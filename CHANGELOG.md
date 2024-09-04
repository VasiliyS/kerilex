# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Removed

### Security

### Fixed

## [0.2.0] - 2024-09-04

### Added
- Out of Order processing of KELs. Useful for incremental KEL/events processing.

- `LogProcessor.process` now accepts existing key states, which allows it to process KELs incrementally.

- Superseding Rotation recovery handling for `rot` events. 
The current implementation will delete all events in the KEL that are coming after the recovery events. 
Need to handle `ixn`s that might have "anchors" - either `seal`s of `ACDC` credentials or delegate events (e.g. `drt` and `dip`).

- Tests for `LogsProcessor`

### Changed
- `LogsProcessor` now relies on the `KeyStateCache` to ensure the order of the events and reduce amount of database lookups.
- `%KeyState` has a changed set of fields.

### Fixed

- Older tests
- Dependency on a local fork of `blake3`.

## [0.1.0] - 2024-08-09

### Added

- The initial release
