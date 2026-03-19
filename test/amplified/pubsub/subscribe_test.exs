defmodule Amplified.PubSub.SubscribeTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Thing
  alias Ecto.UUID

  # ---------------------------------------------------------------------------
  # subscribe/1 — BitString
  # ---------------------------------------------------------------------------

  describe "subscribe/1 with strings" do
    test "subscribes the current process to the channel" do
      PubSub.subscribe("sub:string:test")
      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "sub:string:test", :ping)
      assert_receive :ping
    end

    test "is idempotent — calling twice does not produce duplicate messages" do
      PubSub.subscribe("sub:idempotent")
      PubSub.subscribe("sub:idempotent")
      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "sub:idempotent", :ping)
      assert_receive :ping
      refute_receive :ping
    end
  end

  # ---------------------------------------------------------------------------
  # unsubscribe/1 — BitString
  # ---------------------------------------------------------------------------

  describe "unsubscribe/1 with strings" do
    test "stops messages from arriving" do
      PubSub.subscribe("unsub:string:test")
      PubSub.unsubscribe("unsub:string:test")
      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "unsub:string:test", :ping)
      refute_receive :ping
    end
  end

  # ---------------------------------------------------------------------------
  # subscribe/1 — struct defaults
  # ---------------------------------------------------------------------------

  describe "subscribe/1 with structs" do
    test "subscribes to the derived channel and returns the subject" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}

      assert ^thing = PubSub.subscribe(thing)

      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "thing:#{id}", :ping)
      assert_receive :ping
    end
  end

  # ---------------------------------------------------------------------------
  # unsubscribe/1 — struct defaults
  # ---------------------------------------------------------------------------

  describe "unsubscribe/1 with structs" do
    test "unsubscribes from the derived channel and returns the subject" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}

      PubSub.subscribe(thing)
      assert ^thing = PubSub.unsubscribe(thing)

      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "thing:#{id}", :ping)
      refute_receive :ping
    end
  end

  # ---------------------------------------------------------------------------
  # subscribe/1 — List
  # ---------------------------------------------------------------------------

  describe "subscribe/1 with lists" do
    test "subscribes to each element's channel" do
      id1 = UUID.generate()
      id2 = UUID.generate()
      things = [%Thing{id: id1}, %Thing{id: id2}]

      PubSub.subscribe(things)

      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "thing:#{id1}", :ping1)
      Phoenix.PubSub.broadcast(:amplified_pubsub_test, "thing:#{id2}", :ping2)
      assert_receive :ping1
      assert_receive :ping2
    end
  end

  # ---------------------------------------------------------------------------
  # Unsupported operations raise
  # ---------------------------------------------------------------------------

  describe "Tuple — unsupported operations" do
    test "channel/1 raises" do
      assert_raise RuntimeError, ~r/No channel for/, fn ->
        PubSub.channel({:ok, %Thing{}})
      end
    end

    test "subscribe/1 raises" do
      assert_raise RuntimeError, ~r/Cannot subscribe to/, fn ->
        PubSub.subscribe({:ok, %Thing{}})
      end
    end

    test "unsubscribe/1 raises" do
      assert_raise RuntimeError, ~r/Cannot unsubscribe from/, fn ->
        PubSub.unsubscribe({:ok, %Thing{}})
      end
    end
  end

  describe "Stream — unsupported operations" do
    test "subscribe/1 raises" do
      assert_raise RuntimeError, ~r/Cannot subscribe to/, fn ->
        PubSub.subscribe(Stream.map([], & &1))
      end
    end

    test "unsubscribe/1 raises" do
      assert_raise RuntimeError, ~r/Cannot unsubscribe from/, fn ->
        PubSub.unsubscribe(Stream.map([], & &1))
      end
    end
  end
end
