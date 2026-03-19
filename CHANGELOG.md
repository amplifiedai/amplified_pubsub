# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-20

### Added

- Telemetry event `[:amplified, :pubsub, :broadcast]` emitted on every broadcast with `:topic` and `:message` metadata.
- Explicit `telemetry` dependency (`~> 0.4 or ~> 1.0`).

### Removed

- Direct `Logger` calls from the library. Consuming applications can attach a telemetry handler to log broadcasts instead.

## [0.1.0] - 2026-03-18

### Added

- Protocol-based PubSub dispatch across structs, tuples, lists, streams, and raw channel strings.
- `use Amplified.PubSub` macro for generating protocol implementations with sensible defaults.
- `broadcast/2,3` with transparent `{:ok, _}` / `{:error, _}` tuple handling for Ecto pipeline compatibility.
- `subscribe/1` and `unsubscribe/1` with idempotent subscriptions.
- `handle_info/2,3,4` dispatcher with `{:cont, socket}` / `{:halt, socket}` return convention matching `attach_hook/4`.
- `{:flash, level, message}` automatic handling via `put_flash/3`.
- Namespaced channels (`channel(post, :comments)` → `"post:abc-123:comments"`).
- `defoverridable` support for customising channel derivation and event handling in schema `use` blocks.
- Built-in implementations for `BitString`, `Atom`, `Tuple`, `List`, `Stream`, and `Phoenix.LiveView.Socket`.
