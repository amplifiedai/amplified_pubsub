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

  describe "handle_info/2 — List dispatcher" do
    test "dispatches {struct, message} entries to handle_info/3" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} = PubSub.handle_info([{handled, :updated}], socket)
      assert socket.assigns.handled == handled
    end

    test "dispatches {struct, message, attrs} entries to handle_info/4" do
      handled = %Handled{id: UUID.generate(), name: "test"}
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, socket} =
               PubSub.handle_info([{handled, :updated, %{changed: [:name]}}], socket)

      assert socket.assigns.changed == [:name]
    end

    test "passes through a list this library did not send, rather than crashing" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:cont, ^socket} = PubSub.handle_info([:some, "unrelated", 42], socket)
    end
  end
end
