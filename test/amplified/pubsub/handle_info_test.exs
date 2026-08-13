defmodule Amplified.PubSub.HandleInfoTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Handled
  alias Amplified.PubSubTest.Thing
  alias Ecto.UUID

  describe "handle_info/2 — Tuple dispatcher" do
    test "dispatches {action, subject} to the subject's handle_info/3" do
      id = UUID.generate()
      handled = %Handled{id: id, name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} = PubSub.handle_info({:updated, handled}, socket)
      assert socket.assigns.handled == handled
    end

    test "dispatches {action, subject, attrs} to handle_info/4" do
      id = UUID.generate()
      handled = %Handled{id: id, name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} =
               PubSub.handle_info({:updated, handled, %{changed: [:name]}}, socket)

      assert socket.assigns.changed == [:name]
    end

    test "returns {:cont, socket} for {action, subject} when no custom handler matches" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "foo"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, ^socket} = PubSub.handle_info({:created, thing}, socket)
    end

    test "returns {:cont, socket} for subjects without a protocol implementation" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:cont, ^socket} = PubSub.handle_info({:whatever, 42}, socket)
    end

    test "returns {:cont, socket} for unrecognised tuple shapes" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:cont, ^socket} = PubSub.handle_info({:a, :b, :c, :d}, socket)
    end
  end

  describe "handle_info/2 — batched {event, items} messages" do
    test "dispatches each item to its own handle_info/3" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} = PubSub.handle_info({:updated, [handled]}, socket)
      assert socket.assigns.handled == handled
    end

    test "dispatches each item to its own handle_info/4" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} =
               PubSub.handle_info({:updated, [handled], %{changed: [:name]}}, socket)

      assert socket.assigns.changed == [:name]
    end

    test "threads the socket through every item in the batch" do
      first = %Handled{id: UUID.generate(), name: "first"}
      last = %Handled{id: UUID.generate(), name: "last"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} = PubSub.handle_info({:updated, [first, last]}, socket)
      assert socket.assigns.handled == last
    end

    test "returns {:cont, socket} when no item's handler claims the message" do
      things = [%Thing{id: UUID.generate()}, %Thing{id: UUID.generate()}]
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, ^socket} = PubSub.handle_info({:created, things}, socket)
    end

    test "halts when any item's handler halts, even among items that don't" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} =
               PubSub.handle_info({:updated, [%Thing{id: UUID.generate()}, handled]}, socket)

      assert socket.assigns.handled == handled
    end

    test "an empty batch is a pass-through" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:cont, ^socket} = PubSub.handle_info({:updated, []}, socket)
    end
  end

  describe "handle_info/2 — bare list messages" do
    test "dispatches {struct, message} entries to handle_info/3" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} = PubSub.handle_info([{handled, :updated}], socket)
      assert socket.assigns.handled == handled
    end

    test "dispatches {struct, message, attrs} entries to handle_info/4" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:halt, socket} =
               PubSub.handle_info([{handled, :updated, %{changed: [:name]}}], socket)

      assert socket.assigns.changed == [:name]
    end

    test "passes through a list this library did not send, rather than crashing" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:cont, ^socket} = PubSub.handle_info([:some, "unrelated", 42], socket)
    end
  end
end
