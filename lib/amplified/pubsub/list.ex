defimpl Amplified.PubSub.Protocol, for: List do
  @moduledoc ~S'''
  Protocol implementation for lists.

  Maps PubSub operations across each element of the list. This lets you
  subscribe to or broadcast for a collection of structs in a single call.

  ## Broadcasting

  Items are grouped by channel and a single `{event, items}` message — or
  `{event, items, attrs}` from `broadcast/3` — is sent per channel. This is
  more efficient than broadcasting individually and lets subscribers batch
  whatever work the update implies.

  Each channel's message carries **only the items that live on it**. This is
  the implementation's central guarantee, and
  `Amplified.PubSub.ChannelIsolationTest` exists to hold it.

  The shape matches the one a single struct produces — `{event, subject}` —
  with a list in the subject position, so a receiver reads a batch the same
  way it reads a single item. It does not vary with the number of items: a
  one-element list sends `{event, [item]}`, not `{event, item}`.

  Items wrapped in `{:ok, item}` are unwrapped; `{:error, _}` items are
  silently skipped.

  ## Subscribing

  `subscribe/1` and `unsubscribe/1` operate on each element's channel
  individually.

  ## Channel

  `channel/1` returns a list of channel names, one per element.

  ## Message handling

  The `Tuple` dispatcher unpacks `{event, items}` and finds this
  implementation for the list, calling `handle_info/3` (or `handle_info/4`
  for `{event, items, attrs}`). Both reduce over the items, calling each
  struct's own `handle_info/3,4` and threading the socket through, so
  schema-level handlers fire for batched broadcasts exactly as they do for
  single structs. If any item's handler returns `{:halt, socket}`, the batch
  halts.

  Items with no protocol implementation are skipped. A LiveView sends itself
  plenty of `{action, list}` messages this library knows nothing about, and
  the dispatcher typically runs as a `handle_info` hook — ahead of the
  LiveView's own callback. Skipping is what lets those messages reach the
  handler that wants them.

  `handle_info/2` handles a bare list message — one this implementation
  didn't send, but that a caller can still produce with
  `broadcast("some:channel", [a, b])`. Entries shaped `{struct, message}` or
  `{struct, message, attrs}` are dispatched; anything else passes through, so
  an unrelated list message won't crash the receiving LiveView.

  ## Examples

      posts = [%Post{id: "1"}, %Post{id: "2"}]

      Amplified.PubSub.subscribe(posts)
      # subscribes to "post:1" and "post:2"

      Amplified.PubSub.channel(posts)
      #=> ["post:1", "post:2"]

      Amplified.PubSub.broadcast(posts, :archived)
      # groups by channel, sends {:archived, posts_on_that_channel}

      Amplified.PubSub.broadcast(posts, :archived, %{by: user.id})
      # sends {:archived, posts_on_that_channel, %{by: user.id}}
  '''

  use Amplified.PubSub, impl: true

  def broadcast(items, message) do
    group_by_channel(items, &{message, &1})
    items
  end

  def broadcast(items, message, attrs) do
    group_by_channel(items, &{message, &1, attrs})
    items
  end

  # Each channel gets one message carrying only the items that live on it — never the whole list,
  # which would hand every subscriber the items it did not ask for. `entry` receives just that
  # channel's items, so a leak would have to be introduced here and nowhere else.
  defp group_by_channel(items, entry) do
    items
    |> Stream.flat_map(&extract_tuple/1)
    |> Enum.group_by(&PubSub.channel/1)
    |> Enum.each(fn {channel, items} -> PubSub.broadcast(channel, entry.(items)) end)
  end

  defp extract_tuple({:ok, item}), do: [item]
  defp extract_tuple({:error, _}), do: []
  defp extract_tuple(item), do: [item]

  def channel(list, ns \\ nil), do: Enum.map(list, &PubSub.channel(&1, ns))
  def subscribe(list), do: Enum.map(list, &PubSub.subscribe/1)
  def unsubscribe(list), do: Enum.map(list, &PubSub.unsubscribe/1)

  # Reached via the Tuple dispatcher, which unpacks `{event, items}` and finds this implementation
  # for the list. Without these, a schema's own `handle_info/3,4` would stop firing for batched
  # broadcasts — the batch would arrive at the LiveView but never reach the per-struct handlers.
  def handle_info(list, message, socket),
    do: dispatch_each(list, socket, &PubSub.handle_info(&1, message, &2))

  def handle_info(list, message, attrs, socket),
    do: dispatch_each(list, socket, &PubSub.handle_info(&1, message, attrs, &2))

  # A bare list message, which this implementation no longer sends but a caller still can — e.g.
  # `PubSub.broadcast("some:channel", [a, b])`. Entries of a shape we can read are dispatched;
  # anything else passes through rather than crashing the LiveView that received it.
  def handle_info(list, socket), do: dispatch_each(list, socket, &dispatch_entry/2)

  defp dispatch_entry({struct, message}, socket), do: PubSub.handle_info(struct, message, socket)

  defp dispatch_entry({struct, message, attrs}, socket),
    do: PubSub.handle_info(struct, message, attrs, socket)

  defp dispatch_entry(_entry, socket), do: {:cont, socket}

  # Threads the socket through every item and reports `:halt` if any handler claimed the message,
  # so a batch halts on the same terms a single struct would.
  #
  # Items with no implementation are skipped. The `Tuple` dispatcher guards `{action, subject}` on
  # `impl_for(subject)`, but a list *always* has one — the guard clears the container and says
  # nothing about its contents, so the check has to happen again here, per item.
  defp dispatch_each(list, socket, dispatch) do
    Enum.reduce(list, {:cont, socket}, fn item, {flow, socket} ->
      if PubSub.impl_for(item),
        do: item |> dispatch.(socket) |> merge_flow(flow),
        else: {flow, socket}
    end)
  end

  defp merge_flow({:halt, socket}, _flow), do: {:halt, socket}
  defp merge_flow({:cont, socket}, flow), do: {flow, socket}
end
