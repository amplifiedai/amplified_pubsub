defmodule Amplified.PubSub.BroadcastTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Thing
  alias Ecto.Changeset
  alias Ecto.UUID

  # ---------------------------------------------------------------------------
  # BitString
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with strings" do
    test "delivers message to all subscribers on the topic" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "test:broadcast")
      PubSub.broadcast("test:broadcast", {:hello, :world})
      assert_receive {:hello, :world}
    end

    test "returns the message (not the topic)" do
      assert PubSub.broadcast("test:return", {:hello, :world}) == {:hello, :world}
    end

    test "supports any term as message payload" do
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "test:any_term")
      PubSub.broadcast("test:any_term", "a plain string")
      assert_receive "a plain string"
    end

    test "emits a telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:amplified, :pubsub, :broadcast]
        ])

      PubSub.broadcast("test:telemetry", {:ping, :pong})

      assert_receive {[:amplified, :pubsub, :broadcast], ^ref, %{},
                      %{topic: "test:telemetry", message: {:ping, :pong}}}
    end
  end

  # ---------------------------------------------------------------------------
  # Struct defaults (broadcast/2)
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with structs" do
    test "wraps atom events as {event, subject}" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      assert ^thing = PubSub.broadcast(thing, :updated)
      assert_receive {:updated, ^thing}
    end

    test "wraps string events as {event, subject}" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      PubSub.broadcast(thing, "custom_event")
      assert_receive {"custom_event", ^thing}
    end

    test "broadcasts non-atom/binary events as-is (no wrapping)" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      PubSub.broadcast(thing, {:custom, "payload"})
      assert_receive {:custom, "payload"}
    end

    test "returns the subject for pipeline chaining" do
      thing = %Thing{id: UUID.generate(), name: "foo"}
      assert PubSub.broadcast(thing, :created) == thing
    end
  end

  # ---------------------------------------------------------------------------
  # Struct defaults (broadcast/3 — with attrs)
  # ---------------------------------------------------------------------------

  describe "broadcast/3 with structs" do
    test "wraps atom events with attrs as {event, subject, attrs}" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      PubSub.broadcast(thing, :updated, %{field: :name})
      assert_receive {:updated, ^thing, %{field: :name}}
    end

    test "wraps non-atom events with attrs as {event, attrs}" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      PubSub.broadcast(thing, {:custom, "event"}, %{extra: true})
      assert_receive {{:custom, "event"}, %{extra: true}}
    end

    test "returns the subject" do
      thing = %Thing{id: UUID.generate(), name: "foo"}
      assert PubSub.broadcast(thing, :updated, %{}) == thing
    end
  end

  # ---------------------------------------------------------------------------
  # Atom (no-op)
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with atoms" do
    test "returns the message without broadcasting (no-op)" do
      assert PubSub.broadcast(:ignored, {:some, :message}) == {:some, :message}
    end

    test "broadcast/3 also returns the message (no-op)" do
      assert PubSub.broadcast(:ignored, {:some, :message}, %{}) == {:some, :message}
    end
  end

  # ---------------------------------------------------------------------------
  # Tuple ({:ok, _} and {:error, _})
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with {:ok, subject} tuples" do
    test "unwraps, broadcasts for the subject, and re-wraps as {:ok, subject}" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      assert {:ok, ^thing} = PubSub.broadcast({:ok, thing}, :created)
      assert_receive {:created, ^thing}
    end

    test "passes through {:error, reason} without broadcasting" do
      changeset = %Changeset{}
      assert {:error, ^changeset} = PubSub.broadcast({:error, changeset}, :created)
    end

    test "handles {n, list} tuples (e.g. from Repo.update_all)" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      assert {1, [^thing]} = PubSub.broadcast({1, [thing]}, :created)
      assert_receive {:created, ^thing}
    end
  end

  describe "broadcast/3 with {:ok, subject} tuples" do
    test "unwraps and broadcasts with attrs" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      assert {:ok, ^thing} = PubSub.broadcast({:ok, thing}, :updated, %{field: :name})
      assert_receive {:updated, ^thing, %{field: :name}}
    end

    test "passes through {:error, reason} without broadcasting" do
      changeset = %Changeset{}
      assert {:error, ^changeset} = PubSub.broadcast({:error, changeset}, :updated, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # List
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with lists" do
    test "single-element list broadcasts directly for the item" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      assert [^thing] = PubSub.broadcast([thing], :updated)
      assert_receive {:updated, ^thing}
    end

    test "multi-element list groups items by channel" do
      id1 = UUID.generate()
      id2 = UUID.generate()
      thing1 = %Thing{id: id1, name: "a"}
      thing2 = %Thing{id: id2, name: "b"}

      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id1}")
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id2}")

      assert [^thing1, ^thing2] = PubSub.broadcast([thing1, thing2], :updated)

      # Each channel receives a [{item, event}] list
      assert_receive [{^thing1, :updated}]
      assert_receive [{^thing2, :updated}]
    end

    test "unwraps {:ok, item} tuples and skips {:error, _} items" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      items = [{:ok, thing}, {:error, :something}]
      PubSub.broadcast(items, :created)

      assert_receive [{^thing, :created}]
    end

    test "returns the original list unchanged" do
      things = [%Thing{id: UUID.generate()}, %Thing{id: UUID.generate()}]
      assert PubSub.broadcast(things, :updated) == things
    end
  end

  # ---------------------------------------------------------------------------
  # Stream
  # ---------------------------------------------------------------------------

  describe "broadcast/2 with streams" do
    test "materialises and broadcasts for each item" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      stream = Stream.map([thing], & &1)

      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      PubSub.broadcast(stream, :updated)
      assert_receive {:updated, ^thing}
    end

    test "returns the original stream struct" do
      stream = Stream.map([%Thing{id: UUID.generate()}], & &1)
      assert %Stream{} = PubSub.broadcast(stream, :updated)
    end
  end
end
