defmodule Amplified.PubSub.ChannelIsolationTest do
  @moduledoc """
  Guards the invariant that makes list broadcasting safe: an item is delivered to its own
  channel and to no other.

  This is the property `Enum.group_by(&PubSub.channel/1)` exists to provide, and it is the one
  that failed silently when `broadcast/3` fell through to the default implementation — every
  subscriber received the entire list, including items belonging to channels it had never
  subscribed to.

  Subscribing the test process to several channels cannot detect that: it receives everything
  either way, so a message delivered to the wrong channel still arrives and still matches. These
  tests therefore give **each channel its own process**, so a leak shows up as a message in a
  mailbox that should have stayed empty.

  Any change to the shape of list broadcasts must keep these passing.
  """

  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Custom
  alias Amplified.PubSubTest.Thing
  alias Ecto.UUID

  describe "broadcast/2 with lists — channel isolation" do
    test "an item is delivered only to its own channel" do
      thing1 = %Thing{id: UUID.generate(), name: "a"}
      thing2 = %Thing{id: UUID.generate(), name: "b"}

      sub1 = subscriber(PubSub.channel(thing1))
      sub2 = subscriber(PubSub.channel(thing2))

      PubSub.broadcast([thing1, thing2], :updated)

      assert messages(sub1) == [[{thing1, :updated}]]
      assert messages(sub2) == [[{thing2, :updated}]]
    end

    test "items sharing a channel arrive together, and only there" do
      shared1 = %Custom{id: UUID.generate(), name: "shared"}
      shared2 = %Custom{id: UUID.generate(), name: "shared"}
      other = %Custom{id: UUID.generate(), name: "other"}

      shared_sub = subscriber(PubSub.channel(shared1))
      other_sub = subscriber(PubSub.channel(other))

      PubSub.broadcast([shared1, shared2, other], :updated)

      # One message, batching both items that live on this channel — and nothing from "other".
      assert messages(shared_sub) == [[{shared1, :updated}, {shared2, :updated}]]
      assert messages(other_sub) == [[{other, :updated}]]
    end

    test "a channel with no items in the list receives nothing" do
      thing = %Thing{id: UUID.generate()}
      bystander = subscriber("thing:#{UUID.generate()}")

      PubSub.broadcast([thing, %Thing{id: UUID.generate()}], :updated)

      assert messages(bystander) == []
    end

    test "skipped {:error, _} items do not leak to any channel" do
      thing = %Thing{id: UUID.generate()}
      sub = subscriber(PubSub.channel(thing))

      PubSub.broadcast([{:ok, thing}, {:error, :nope}], :created)

      assert messages(sub) == [[{thing, :created}]]
    end
  end

  describe "broadcast/3 with lists — channel isolation" do
    test "an item is delivered only to its own channel" do
      thing1 = %Thing{id: UUID.generate(), name: "a"}
      thing2 = %Thing{id: UUID.generate(), name: "b"}
      attrs = %{changed: [:name]}

      sub1 = subscriber(PubSub.channel(thing1))
      sub2 = subscriber(PubSub.channel(thing2))

      PubSub.broadcast([thing1, thing2], :updated, attrs)

      assert messages(sub1) == [[{thing1, :updated, attrs}]]
      assert messages(sub2) == [[{thing2, :updated, attrs}]]
    end

    test "items sharing a channel arrive together, and only there" do
      shared1 = %Custom{id: UUID.generate(), name: "shared3"}
      shared2 = %Custom{id: UUID.generate(), name: "shared3"}
      other = %Custom{id: UUID.generate(), name: "other3"}
      attrs = %{n: 1}

      shared_sub = subscriber(PubSub.channel(shared1))
      other_sub = subscriber(PubSub.channel(other))

      PubSub.broadcast([shared1, shared2, other], :updated, attrs)

      assert messages(shared_sub) == [[{shared1, :updated, attrs}, {shared2, :updated, attrs}]]
      assert messages(other_sub) == [[{other, :updated, attrs}]]
    end

    test "a channel with no items in the list receives nothing" do
      bystander = subscriber("thing:#{UUID.generate()}")

      PubSub.broadcast([%Thing{id: UUID.generate()}], :updated, %{})

      assert messages(bystander) == []
    end
  end

  describe "broadcast/3 with streams — channel isolation" do
    test "an item is delivered only to its own channel" do
      thing1 = %Thing{id: UUID.generate()}
      thing2 = %Thing{id: UUID.generate()}

      sub1 = subscriber(PubSub.channel(thing1))
      sub2 = subscriber(PubSub.channel(thing2))

      PubSub.broadcast(Stream.map([thing1, thing2], & &1), :archived, %{})

      assert messages(sub1) == [[{thing1, :archived, %{}}]]
      assert messages(sub2) == [[{thing2, :archived, %{}}]]
    end
  end

  # A process subscribed to exactly one channel, so anything in its mailbox that doesn't belong
  # to that channel is a leak.
  defp subscriber(channel) do
    test = self()

    pid =
      spawn_link(fn ->
        Phoenix.PubSub.subscribe(:amplified_pubsub_test, channel)
        send(test, {:ready, self()})
        collect([])
      end)

    receive do
      {:ready, ^pid} -> pid
    after
      1000 -> flunk("subscriber for #{channel} never signalled ready")
    end
  end

  defp collect(received) do
    receive do
      {:report, from} -> send(from, {:messages, Enum.reverse(received)})
      message -> collect([message | received])
    end
  end

  # `Phoenix.PubSub` dispatches to local subscribers from the calling process, so every broadcast
  # send happens before this one. Message order between two processes is guaranteed, so the report
  # arrives last and needs no sleep to settle.
  defp messages(pid) do
    send(pid, {:report, self()})

    receive do
      {:messages, messages} -> messages
    after
      1000 -> flunk("subscriber never reported")
    end
  end
end
