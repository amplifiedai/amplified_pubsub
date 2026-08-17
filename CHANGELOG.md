# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-08-17

### Fixed

- `handle_info` no longer raises `Protocol.UndefinedError` on a `{event, items}` message whose items
  have no protocol implementation. Items without one are now skipped.

  The `Tuple` dispatcher guards `{event, subject}` on `impl_for(subject)`, but a list always has an
  implementation — so the guard cleared the container and said nothing about its contents. `List`
  then fanned out to every item unguarded. Any `{event, [%NotASubject{}, ...]}` message raised.

  This reached applications through their own messages, not through broadcasts. A LiveView sending
  itself `{:saved, [%SomeResult{}, ...]}` from a component was enough, and because the dispatcher is
  usually attached as a `handle_info` hook, it raised *ahead* of the LiveView's own callback — the
  handler written for the message never got to run.

  Introduced in 0.3.0 along with `List.handle_info/3,4`; releases before that had no `List`
  `handle_info/3`, so these messages fell through untouched.

## [0.3.0] - 2026-08-13

### Changed

- **BREAKING.** List broadcasts now send `{event, items}` per channel — `{event, items, attrs}`
  from `broadcast/3` — instead of `[{item, event}, ...]`. The subject sits where it sits for a
  single struct, with a list in it, so a receiver reads a batch the same way it reads one item.

  Batching is unchanged: items are still grouped by channel, still one message per channel, still
  carrying only that channel's items. Only the nesting differs.

  The shape also no longer varies with the number of items. Previously a one-element list was
  special-cased and delegated to the item, so `broadcast([post], :archived)` sent
  `{:archived, post}` while `broadcast([a, b], :archived)` sent `[{a, :archived}, {b, :archived}]`
  — one shape or the other depending on how many rows a query happened to return. Consumers had to
  write two handlers for one event and keep them in step. Now both send the list form.

  Migration — the two handlers collapse into one, and the unwrapping goes away:

      # before
      def handle_info({:archived, %Post{} = post}, socket), do: archive([post], socket)

      def handle_info([{%Post{}, :archived} | _] = list, socket),
        do: list |> Enum.map(&elem(&1, 0)) |> archive(socket)

      # after
      def handle_info({:archived, [%Post{} | _] = posts}, socket), do: archive(posts, socket)

  A handler for a **bare struct** broadcast (`broadcast(post, :archived)`) is unaffected and still
  matches `{:archived, %Post{}}`. Only broadcasts whose subject is a list or stream change.

### Documentation

- The moduledoc's claim that "the defaults always return `{:cont, socket}`, so unmatched messages
  fall through safely" only held until you overrode something. A function defined in a
  `use Amplified.PubSub do ... end` block **replaces** the default of that name and arity rather
  than adding a clause ahead of it, so defining one `handle_info/3` removes the catch-all and an
  unmatched event raises `FunctionClauseError` in the receiving LiveView. That is `defoverridable`
  behaving normally and overriding means owning the whole function, but the failure lands in a
  process far from the schema, so it is now called out with the remedy — end your handlers with a
  catch-all. Pre-existing behaviour, unchanged; only the documentation was wrong.

  Covered by `Amplified.PubSub.OverrideTest`, which also pins the fact that the arities are
  independent: overriding `handle_info/3` leaves the `handle_info/4` default intact.

### Added

- `Amplified.PubSub.EventIsolationTest`, guarding the other half of batch integrity: a batch carries
  the event its own broadcast call was given, applied to every item in that call and to no items
  from any other. `ChannelIsolationTest` asks whether the right *items* reached a channel; this asks
  whether they arrived under the right *event*.

  The old shape paired an event with each item, which looks like a per-item guarantee but is not
  one — every pair drew on the same single `message` argument, so the pairing repeated one value N
  times rather than establishing anything about any item. `{event, items}` binds that same value
  once. Both derive the event from the scalar argument to the call, so neither can associate an item
  with an event the caller didn't ask for. These tests exist so that a refactor threading the event
  differently fails loudly.

### Fixed

- Schema-level `handle_info/3,4` now fire for batched broadcasts. The `Tuple` dispatcher unpacks
  `{event, items}` and finds the `List` implementation, which reduces over the items calling each
  struct's own handler — previously `List` inherited the injected pass-through for those arities,
  so a naive move to this shape would have silently stopped per-struct handlers from running.
- A `{:halt, socket}` from an item's handler halts the batch. `List.handle_info/2` took `elem(1)`
  of each result and always reported `{:cont, socket}`, silently downgrading a handler that had
  claimed the message.

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
