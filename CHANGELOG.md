# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-08-13

### Fixed

- `broadcast/3` on a list no longer sends a malformed message. `List` implemented `broadcast/2`
  but not `broadcast/3`, so the three-arity call fell through to the default injected by
  `use Amplified.PubSub`, which derives a channel from the subject — and a list's `channel/1` is a
  *list* of channels. That list was then broadcast as if it were the subject, so every subscriber
  received `[{their_channel_name, {event, the_entire_list, attrs}}]`: the wrong shape, so
  `handle_info/2` never matched it and returned `{:cont, socket}` with no error, and the wrong
  contents, since each subscriber was handed every other channel's items as well as its own.
  `List.broadcast/3` now mirrors `broadcast/2` — a single-element list delegates to the item, and a
  multi-element list groups by channel and sends `[{item, event, attrs}, ...]` carrying only the
  items on that channel.
- `List.handle_info/2` dispatches `{item, event, attrs}` entries to `handle_info/4`, which is what
  the corrected `broadcast/3` now sends.
- `List.handle_info/2` passes through a list it did not send instead of raising `FunctionClauseError`.
  A LiveView with the PubSub hook attached previously crashed on any unrelated list message.
- `List.unsubscribe/1` unsubscribes. It called `subscribe/1` on each element, so unsubscribing from
  a list of subjects subscribed to them instead.
- `Stream.broadcast/3` materialises the stream. It had the same missing-clause fault as `List`, and
  additionally sent the unevaluated `%Stream{}` struct itself over the wire.
- `Tuple.broadcast/3` handles `{n, list}` tuples (as returned by `Repo.update_all/3`), matching
  `broadcast/2`. It previously fell through to the `{:error, _}` clause and broadcast nothing at all.

### Added

- `Amplified.PubSub.ChannelIsolationTest`, guarding the invariant that a list broadcast delivers
  each item to its own channel and to no other. Each channel gets its own subscriber process, so a
  leak surfaces as a message in a mailbox that should have stayed empty — the pre-existing list
  tests subscribed one process to every channel, which cannot distinguish correct routing from a
  message delivered everywhere. Any change to the shape of list broadcasts must keep these passing.

## [0.2.1] - 2026-06-16

### Fixed

- Elixir 1.20 compatibility. The generated struct `channel/2` no longer trips the new type
  checker's "redundant clause" warning in consuming applications, and
  `Amplified.PubSub.Protocol` no longer uses a deprecated default argument in its `channel`
  definition. No behaviour change.

## [0.2.0] - 2026-03-20

### Added

- Telemetry event `[:amplified, :pubsub, :broadcast]` emitted on every broadcast with `:topic` and `:message` metadata.
- Explicit `telemetry` dependency (`~> 0.4 or ~> 1.0`).

### Removed

- Direct `Logger` calls from the library. Consuming applications can attach a telemetry handler to log broadcasts instead.

### Fixed

- Corrected GitHub organisation URLs
- Improved documentation to better advise best practices

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
