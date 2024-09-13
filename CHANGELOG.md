# Changelog

## [0.2.1]- 2024-09-11

### Changed
- Update `CHANGELOG.md` to follow [`Common Changelog`](https://common-changelog.org)

### Added
- Implement key state storage functionality (`get_ks`, `maybe_update_ks`)
- Verify `opts` passed to `LogsProcessor.process_kel`

### Fixed
- Refactor `LogsProcessor.process_kel` for better code readability

[0.2.1]: https://github.com/VasiliyS/kerilex/releases/tag/0.2.1

## [0.2.0] - 2024-09-04

### Added
- Implement "out of order" processing of KELs. Useful for incremental KEL/events processing.

- Add `opts` parameter to `LogProcessor.process_kel` to accept existing key states, which allows it to process KELs incrementally.

- Implement Superseding Rotation recovery handling for `rot` events. 

    _Note:_ The current implementation will delete all events in the KEL that are coming after the recovery events. 
Need to handle `ixn`s that might have "anchors" - either `seal`s of `ACDC` credentials or delegate events (e.g. `drt` and `dip`).

- Implement tests for `LogsProcessor`

### Changed
- Refactor `LogsProcessor` to rely on the `KeyStateCache` to ensure the order of the events and reduce amount of database lookups.
- Rename `%KeyState` fields and add `last_event`.

### Fixed

- Make older tests work
- Remove dependency on a local fork of `blake3`.

[0.2.0]: https://github.com/VasiliyS/kerilex/releases/tag/0.2.0

## 0.1.0 - 2024-08-09

 _The initial release_
