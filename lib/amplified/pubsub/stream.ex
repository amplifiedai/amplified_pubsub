defimpl Amplified.PubSub.Protocol, for: Stream do
  @moduledoc """
  Protocol implementation for streams.

  Materialises the stream to a list and delegates to the `List`
  implementation. The original stream is returned from `broadcast/2,3`
  (not the materialised list).

  Subscribing and unsubscribing to streams is not supported and will raise.

  ## Examples

      stream = Stream.map(posts, & &1)

      Amplified.PubSub.broadcast(stream, :updated)
      # materialises stream, broadcasts for each item, returns the stream

      Amplified.PubSub.channel(stream)
      #=> ["post:1", "post:2"]

  """

  use Amplified.PubSub, impl: true

  def broadcast(stream, message) do
    stream |> Enum.to_list() |> PubSub.broadcast(message)
    stream
  end

  def broadcast(stream, message, attrs) do
    stream |> Enum.to_list() |> PubSub.broadcast(message, attrs)
    stream
  end

  def channel(stream, ns \\ nil), do: stream |> Enum.to_list() |> PubSub.channel(ns)
  def subscribe(stream), do: raise("Cannot subscribe to #{inspect(stream)}")
  def unsubscribe(stream), do: raise("Cannot unsubscribe from #{inspect(stream)}")
end
