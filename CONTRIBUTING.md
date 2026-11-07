# Contributing to ValtSky

Thank you for your interest in contributing to **ValtSky**! ValtSky is an open-source, aircraft-grade multiplatform cloud vault airframe built with Flutter & Dart, engineered under the **ADE STD 100** aerospace documentation and reliability standard.

---

## Code of Conduct

All contributors, maintainers, and community participants are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before participating.

---

## Architectural Principles (ADE STD 100)

Every contribution must honor our five non-negotiable core invariants:

1. **Zero Loss (100% Bit-for-Bit)**: Never re-encode images or strip camera metadata/EXIF/ICC tags. Files must transmit via document payloads.
2. **Monotonic Chronological Ordering**: Assets must be queued and archived in strict ascending order by original capture timestamp ($T_i \le T_{i+1}$).
3. **Bounded Memory Footprint**: Heap usage must remain flat ($O(1)$ RAM, bounded $< 28\text{ MB}$) regardless of payload size (up to 4 GB). Use streamed socket slices and file descriptors.
4. **Resilient Self-Healing**: Background workers must handle transient offline drops, rate limits (HTTP 429 / `FLOOD_WAIT`), and socket invalidations with deterministic capped backoff without crashing or entering infinite loops.
5. **No Layout Overflow Under 320px**: All UI decks must fit within tight viewports (down to 320px width) using `Flexible` bounds and `FittedBox` scaling without triggering Flutter `RenderFlex` overflow errors.

---

## Development Setup

### Prerequisites
- **Flutter SDK**: 3.24.x or newer (`stable` channel)
- **Dart SDK**: 3.5.x or newer
- **JDK**: Java 17 (Temurin recommended)
- **Android Studio / VS Code**: With Flutter & Dart plugins
- **ADB**: Android Debug Bridge installed and available on `PATH`

### Getting the Code
```bash
git clone https://github.com/Reddirector/ValtSky.git
cd ValtSky/valtsky_flutter
flutter pub get
```

### Running Tests (Mandatory Before PR)
All automated flight tests must pass concurrently with 0 warnings:

```bash
# 1. Run static analysis
flutter analyze

# 2. Run full test suite (42/42 tests)
flutter test --reporter expanded
```

---

## Pull Request Guidelines

1. **Branch Naming**:
   - `feat/feature-name`
   - `fix/bug-fix-name`
   - `docs/documentation-update`
   - `perf/performance-optimization`

2. **Commit Message Format (Conventional Commits)**:
   ```
   <type>(<scope>): <short imperative description>

   [optional detailed body]
   ```
   *Examples:*
   - `feat(sync): add adaptive multi-worker pool scaling`
   - `fix(lifecycle): await background service start and synchronize parent views`
   - `docs(manual): update ATA Chapter 20 with new BITE telemetry diagrams`

3. **Test-Driven Development (TDD)**:
   - Any new feature or bugfix must be accompanied by automated regression unit tests in `valtsky_flutter/test/`.
   - Maintain 100% passing status across all existing flight suites.

4. **Code Quality**:
   - Run `flutter analyze` — zero errors, zero warnings, zero hints allowed.
   - Keep functions concise (< 50 lines) and cohesive.
   - Avoid mutable state leaks; dispose controllers, timers, and streams cleanly in `dispose()`.

---

## Dual-License Agreement

By contributing to ValtSky, you agree that your contributions will be dual-licensed under both the **MIT License** and the **Apache License, Version 2.0**.
