defmodule Amplified.PubSub.ChannelTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Custom
  alias Amplified.PubSubTest.Recorder
  alias Amplified.PubSubTest.Thing
  alias Ecto.Changeset
  alias Ecto.UUID

  # ---------------------------------------------------------------------------
  # Struct defaults (via `use Amplified.PubSub`)
  # ---------------------------------------------------------------------------

  describe "channel/2 with structs" do
    test "derives channel from the module's last segment and struct id" do
      id = UUID.generate()
      assert PubSub.channel(%Thing{id: id}) == "thing:#{id}"
    end

    test "works on a bare defstruct — the protocol doesn't require Ecto" do
      id = UUID.generate()
      assert PubSub.channel(%Recorder{id: id}) == "recorder:#{id}"
    end

    test "snake_cases multi-word module names" do
      # Thing -> "thing" (single word, but verifies the Recase pipeline)
      assert PubSub.channel(%Thing{id: "1"}) == "thing:1"
    end

    test "appends a string namespace" do
      id = UUID.generate()
      assert PubSub.channel(%Thing{id: id}, "drafts") == "thing:#{id}:drafts"
    end

    test "appends an atom namespace" do
      id = UUID.generate()
      assert PubSub.channel(%Thing{id: id}, :edit) == "thing:#{id}:edit"
    end

    test "returns channel with empty id segment for structs with nil id" do
      assert PubSub.channel(%Thing{}) == "thing:"
    end

    test "raises for a struct without a protocol implementation" do
      assert_raise Protocol.UndefinedError, fn ->
        PubSub.channel(%Changeset{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Custom override (via defimpl)
  # ---------------------------------------------------------------------------

  describe "channel/2 with custom implementation" do
    test "uses the custom channel derivation" do
      assert PubSub.channel(%Custom{name: "widgets"}) == "custom:widgets"
    end

    test "ignores namespace since the custom impl doesn't use it" do
      assert PubSub.channel(%Custom{name: "widgets"}, :edit) == "custom:widgets"
    end
  end

  # ---------------------------------------------------------------------------
  # BitString
  # ---------------------------------------------------------------------------

  describe "channel/2 with strings" do
    test "returns the string unchanged" do
      assert PubSub.channel("my:channel") == "my:channel"
    end

    test "appends namespace with colon separator" do
      assert PubSub.channel("my:channel", "ns") == "my:channel:ns"
    end

    test "nil namespace returns channel unchanged" do
      assert PubSub.channel("my:channel", nil) == "my:channel"
    end
  end

  # ---------------------------------------------------------------------------
  # Atom
  # ---------------------------------------------------------------------------

  describe "channel/2 with atoms" do
    test "converts atom to string" do
      assert PubSub.channel(:users) == "users"
    end

    test "appends namespace" do
      assert PubSub.channel(:users, :admin) == "users:admin"
    end
  end

  # ---------------------------------------------------------------------------
  # List
  # ---------------------------------------------------------------------------

  describe "channel/2 with lists" do
    test "returns a list of channels, one per element" do
      id1 = UUID.generate()
      id2 = UUID.generate()

      assert PubSub.channel([%Thing{id: id1}, %Thing{id: id2}]) == [
               "thing:#{id1}",
               "thing:#{id2}"
             ]
    end

    test "returns empty list for empty input" do
      assert PubSub.channel([]) == []
    end

    test "applies namespace to every element" do
      channels = PubSub.channel([%Thing{id: "1"}, %Thing{id: "2"}], :edit)
      assert channels == ["thing:1:edit", "thing:2:edit"]
    end
  end

  # ---------------------------------------------------------------------------
  # Stream
  # ---------------------------------------------------------------------------

  describe "channel/2 with streams" do
    test "materialises the stream and returns channels" do
      id = UUID.generate()
      stream = Stream.map([%Thing{id: id}], & &1)
      assert PubSub.channel(stream) == ["thing:#{id}"]
    end
  end
end
