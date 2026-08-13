defmodule Amplified.PubSub.EventIsolationTest do
  @moduledoc """
  Guards the other half of batch integrity: a batch carries the event its own broadcast call was
  given, applied to every item in that call and to no items from any other.

  `ChannelIsolationTest` asks whether the right *items* reached a channel. This asks whether they
  arrived under the right *event*.

  The old `[{item, event}, ...]` shape paired an event with each item, which looks like a per-item
  guarantee but is not one: every pair drew on the same single `message` argument, so the pairing
  repeated one value N times rather than establishing anything about any item. `{event, items}`
  binds that same value once, for the group. Both shapes derive the event from the same place — the
  scalar argument to the call — so neither can associate an item with an event the caller didn't
  ask for.

  What holds the property is that `message` is closed over by the `entry` function built in
  `broadcast/2,3` and applied per group, so there is only ever one event value in scope for a call.
  These tests exist so that a refactor which threads the event differently — deriving it from the
  items, accumulating groups across calls, reusing a builder — fails loudly.
  """

  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Custom
  alias Amplified.PubSubTest.Recorder
  alias Amplified.PubSubTest.Thing
  alias Ecto.UUID

  describe "broadcast — event binding" do
    test "each call's items arrive under that call's event" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev1")
      created1 = %Custom{id: UUID.generate(), name: "ev1"}
      created2 = %Custom{id: UUID.generate(), name: "ev1"}
      deleted = %Custom{id: UUID.generate(), name: "ev1"}

      PubSub.broadcast([created1, created2], :created)
      PubSub.broadcast([deleted], :deleted)

      # Neither batch may borrow the other's event, nor absorb its items.
      assert_receive {:created, [^created1, ^created2]}
      assert_receive {:deleted, [^deleted]}
      refute_receive _
    end

    test "every item in a batch is governed by the call's event" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev2")
      items = for _ <- 1..3, do: %Custom{id: UUID.generate(), name: "ev2"}

      PubSub.broadcast(items, :archived)

      assert_receive {:archived, ^items}
      refute_receive _
    end

    test "the same items broadcast under a second event do not retain the first" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev3")
      items = [%Custom{id: UUID.generate(), name: "ev3"}]

      PubSub.broadcast(items, :created)
      PubSub.broadcast(items, :updated)

      assert_receive {:created, ^items}
      assert_receive {:updated, ^items}
      refute_receive _
    end

    test "events do not cross between channels broadcast in separate calls" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev4a")
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev4b")
      a = %Custom{id: UUID.generate(), name: "ev4a"}
      b = %Custom{id: UUID.generate(), name: "ev4b"}

      PubSub.broadcast([a], :created)
      PubSub.broadcast([b], :deleted)

      assert_receive {:created, [^a]}
      assert_receive {:deleted, [^b]}
      refute_receive _
    end

    test "one call spanning several channels applies its event to all of them" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev5a")
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev5b")
      a = %Custom{id: UUID.generate(), name: "ev5a"}
      b = %Custom{id: UUID.generate(), name: "ev5b"}

      PubSub.broadcast([a, b], :archived)

      assert_receive {:archived, [^a]}
      assert_receive {:archived, [^b]}
      refute_receive _
    end

    test "broadcast/3 carries the call's event and attrs to every item" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev6")
      items = [%Custom{id: UUID.generate(), name: "ev6"}]

      PubSub.broadcast(items, :updated, %{by: "someone"})
      PubSub.broadcast(items, :deleted, %{by: "someone else"})

      assert_receive {:updated, ^items, %{by: "someone"}}
      assert_receive {:deleted, ^items, %{by: "someone else"}}
      refute_receive _
    end

    test "a string event is bound the same way an atom one is" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "custom:ev7")
      items = [%Custom{id: UUID.generate(), name: "ev7"}]

      PubSub.broadcast(items, "custom_event")

      assert_receive {"custom_event", ^items}
    end
  end

  describe "handle_info — event binding" do
    test "every item in a batch is dispatched under the batch's event" do
      first = %Recorder{id: UUID.generate()}
      last = %Recorder{id: UUID.generate()}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} = PubSub.handle_info({:archived, [first, last]}, socket)
      assert socket.assigns.seen == [{first.id, :archived}, {last.id, :archived}]
    end

    test "a second batch's event does not reach the first batch's items" do
      first = %Recorder{id: UUID.generate()}
      last = %Recorder{id: UUID.generate()}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} = PubSub.handle_info({:created, [first]}, socket)
      assert {:cont, socket} = PubSub.handle_info({:deleted, [last]}, socket)

      assert socket.assigns.seen == [{first.id, :created}, {last.id, :deleted}]
    end

    test "attrs reach handle_info/4 under the batch's own event" do
      recorder = %Recorder{id: UUID.generate()}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} =
               PubSub.handle_info({:updated, [recorder], %{changed: [:name]}}, socket)

      assert socket.assigns.seen == [{recorder.id, :updated, %{changed: [:name]}}]
    end

    test "a string event is dispatched intact, not coerced" do
      recorder = %Recorder{id: UUID.generate()}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} = PubSub.handle_info({"custom_event", [recorder]}, socket)
      assert socket.assigns.seen == [{recorder.id, "custom_event"}]
    end
  end

  describe "old-shape lists" do
    # The migration safety net. A caller still constructing `[{item, event}, ...]` must not have
    # those pairs quietly treated as items and rebound to whatever event the call passed — it
    # raises in `Tuple.channel/2` instead, which is loud and points at the call site.
    test "a list of {item, event} pairs raises rather than rebinding the event" do
      thing = %Thing{id: UUID.generate()}

      assert_raise RuntimeError, ~r/No channel for/, fn ->
        PubSub.broadcast([{thing, :created}, {thing, :updated}], :archived)
      end
    end
  end
end
