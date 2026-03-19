defmodule Amplified.PubSub.ConfigTest do
  use ExUnit.Case, async: true

  alias Amplified.PubSub

  describe "pubsub_server/0" do
    test "returns the configured PubSub server name" do
      assert PubSub.pubsub_server() == :amplified_pubsub_test
    end
  end
end
