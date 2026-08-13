defimpl Amplified.PubSub.Protocol, for: List do
  @moduledoc ~S'''
  Protocol implementation for lists.

  Maps PubSub operations across each element of the list. This lets you
  subscribe to or broadcast for a collection of structs in a single call.

  ## Broadcasting

  For a single-element list, `broadcast/2` and `broadcast/3` delegate
  directly to the element's implementation.

  For multi-element lists, items are grouped by channel and a single
  `[{item, event}, ...]` message — or `[{item, event, attrs}, ...]` from
  `broadcast/3` — is sent per channel. This is more efficient than
  broadcasting individually and lets subscribers receive batch updates.
  Each channel's message carries only the items that live on it. Items
  wrapped in `{:ok, item}` are unwrapped; `{:error, _}` items are silently
  skipped.

  ## Subscribing

  `subscribe/1` and `unsubscribe/1` operate on each element's channel
  individually.

  ## Channel

  `channel/1` returns a list of channel names, one per element.

  ## Message handling

  `handle_info/2` expects a list of `{struct, message}` or
  `{struct, message, attrs}` tuples (as produced by the multi-element
  broadcasts). It reduces over the list, calling each struct's
  `handle_info/3` or `handle_info/4` and threading the socket through.
  Entries of any other shape are ignored, so an unrelated list message
  won't crash the receiving LiveView.

  ## Examples

      posts = [%Post{id: "1"}, %Post{id: "2"}]

      Amplified.PubSub.subscribe(posts)
      # subscribes to "post:1" and "post:2"

      Amplified.PubSub.channel(posts)
      #=> ["post:1", "post:2"]

      Amplified.PubSub.broadcast(posts, :archived)
      # groups by channel, sends [{post, :archived}] per channel

      Amplified.PubSub.broadcast(posts, :archived, %{by: user.id})
      # sends [{post, :archived, %{by: user.id}}] per channel
  '''

  use Amplified.PubSub, impl: true

  def broadcast([item], message), do: [PubSub.broadcast(item, message)]

  def broadcast(items, message) do
    group_by_channel(items, &{&1, message})
    items
  end

  def broadcast([item], message, attrs), do: [PubSub.broadcast(item, message, attrs)]

  def broadcast(items, message, attrs) do
    group_by_channel(items, &{&1, message, attrs})
    items
  end

  # Each channel gets one message carrying only the items that live on it — never the whole list,
  # which would hand every subscriber the items it did not ask for.
  defp group_by_channel(items, entry) do
    items
    |> Stream.flat_map(&extract_tuple/1)
    |> Enum.group_by(&PubSub.channel/1)
    |> Enum.each(fn {channel, items} ->
      items |> Enum.map(entry) |> then(&PubSub.broadcast(channel, &1))
    end)
  end

  defp extract_tuple({:ok, item}), do: [item]
  defp extract_tuple({:error, _}), do: []
  defp extract_tuple(item), do: [item]

  def channel(list, ns \\ nil), do: Enum.map(list, &PubSub.channel(&1, ns))
  def subscribe(list), do: Enum.map(list, &PubSub.subscribe/1)
  def unsubscribe(list), do: Enum.map(list, &PubSub.unsubscribe/1)

  def handle_info(list, socket) do
    list
    |> Enum.reduce(socket, &dispatch/2)
    |> then(&{:cont, &1})
  end

  defp dispatch({struct, message}, socket),
    do: struct |> PubSub.handle_info(message, socket) |> elem(1)

  defp dispatch({struct, message, attrs}, socket),
    do: struct |> PubSub.handle_info(message, attrs, socket) |> elem(1)

  # A list this implementation did not send. Pass it through rather than crashing the LiveView that
  # happened to receive it, which is what every other implementation does with a message it can't
  # read.
  defp dispatch(_entry, socket), do: socket
end
