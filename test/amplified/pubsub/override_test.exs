defmodule Amplified.PubSub.OverrideTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Partial

  describe "overriding a handle_info arity" do
    test "the overridden clause still matches its own event" do
      socket = %Phoenix.LiveView.Socket{}
      assert {:halt, socket} = PubSub.handle_info({:updated, %Partial{id: "a"}}, socket)
      assert socket.assigns.hit
    end

    test "an event the override doesn't match raises — the catch-all was replaced" do
      socket = %Phoenix.LiveView.Socket{}

      assert_raise FunctionClauseError, fn ->
        PubSub.handle_info({:deleted, %Partial{id: "a"}}, socket)
      end
    end

    test "overriding handle_info/3 leaves the handle_info/4 default intact" do
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, ^socket} =
               PubSub.handle_info({:anything, %Partial{id: "a"}, %{a: 1}}, socket)
    end

    test "a batch of them raises too — batching doesn't add a safety net" do
      socket = %Phoenix.LiveView.Socket{}

      assert_raise FunctionClauseError, fn ->
        PubSub.handle_info({:deleted, [%Partial{id: "a"}]}, socket)
      end
    end
  end
end
