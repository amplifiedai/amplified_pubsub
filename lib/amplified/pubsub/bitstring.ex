defimpl Amplified.PubSub.Protocol, for: BitString do
  @moduledoc """
  Protocol implementation for strings (bitstrings).

  Treats the string as a literal PubSub channel name. This is the
  foundation that all other implementations ultimately delegate to for
  the actual `Phoenix.PubSub` calls.

  ## Behaviour

    * `broadcast/2` — calls `Phoenix.PubSub.broadcast/3` with the
      configured PubSub server, the string as the topic, and the message.
      Returns the message. Emits a `[:amplified, :pubsub, :broadcast]`
      telemetry event with `%{topic: topic, message: message}` metadata.

    * `channel/2` — returns the string as-is, or appends the namespace
      with a `:` separator when provided.

    * `subscribe/1` — unsubscribes first (to prevent duplicates), then
      subscribes via the configured PubSub server.

    * `unsubscribe/1` — unsubscribes via the configured PubSub server.

  ## Examples

      Amplified.PubSub.broadcast("room:lobby", {:user_joined, user})
      #=> {:user_joined, user}

      Amplified.PubSub.channel("room:lobby")
      #=> "room:lobby"

      Amplified.PubSub.channel("room:lobby", :typing)
      #=> "room:lobby:typing"

  """

  use Amplified.PubSub, impl: true
  alias Amplified.PubSub, as: Ampd
  alias Phoenix.PubSub

  def broadcast(topic, message) do
    PubSub.broadcast(Ampd.pubsub_server(), topic, message)
    :telemetry.execute([:amplified, :pubsub, :broadcast], %{}, %{topic: topic, message: message})
    message
  end

  def channel(channel, ns \\ nil)
  def channel(channel, nil), do: channel
  def channel(channel, ns), do: "#{channel}:#{ns}"

  def subscribe(channel) do
    server = Ampd.pubsub_server()
    PubSub.unsubscribe(server, channel)
    PubSub.subscribe(server, channel)
  end

  def unsubscribe(channel), do: PubSub.unsubscribe(Ampd.pubsub_server(), channel)
end
