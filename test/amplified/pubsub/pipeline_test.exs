defmodule Amplified.PubSub.PipelineTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub
  alias Amplified.PubSubTest.Thing
  alias Ecto.Changeset
  alias Ecto.UUID

  describe "end-to-end CRUD pipeline" do
    test "broadcast chains through {:ok, struct} simulating Repo.insert" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "new thing"}
      Phoenix.PubSub.subscribe(:amplified_pubsub_test, "thing:#{id}")

      result = {:ok, thing} |> PubSub.broadcast(:created)

      assert {:ok, ^thing} = result
      assert_receive {:created, ^thing}
    end

    test "broadcast passes through {:error, changeset}" do
      changeset = %Changeset{valid?: false}
      result = {:error, changeset} |> PubSub.broadcast(:created)
      assert {:error, ^changeset} = result
    end

    test "full cycle: subscribe, broadcast, receive" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "cycled"}

      PubSub.subscribe(thing)
      PubSub.broadcast({:ok, thing}, :updated)
      assert_receive {:updated, ^thing}
    end

    test "broadcast with attrs through the full pipeline" do
      id = UUID.generate()
      thing = %Thing{id: id, name: "attrs_test"}
      PubSub.subscribe(thing)

      PubSub.broadcast({:ok, thing}, :updated, %{changed_fields: [:name]})
      assert_receive {:updated, ^thing, %{changed_fields: [:name]}}
    end
  end
end
