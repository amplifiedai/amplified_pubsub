defimpl Amplified.PubSub.Protocol, for: Tuple do
  @moduledoc ~S'''
  Protocol implementation for tuples.

  This is one of the most important implementations — it's what makes
  `Amplified.PubSub` pipeline-friendly with Ecto operations. It handles
  `{:ok, subject}` and `{:error, reason}` tuples from Repo calls, and it
  dispatches incoming `{action, subject}` messages in `handle_info`.

  ## Broadcasting

  `broadcast/2` pattern-matches on the tuple shape:

    * `{:ok, subject}` — unwraps the subject, delegates `broadcast/2` to
      the subject's protocol implementation, and re-wraps as `{:ok, subject}`.

    * `{n, list}` when `list` is a list — broadcasts for the list and
      returns `{n, list}` unchanged. This handles patterns like
      `Repo.update_all` which returns `{count, records}`.

    * `{:error, _}` and other tuples — passed through unchanged.

  ## Message dispatching

  `handle_info/2` is the primary message dispatcher, called from your
  LiveView's `handle_info/2`. It pattern-matches on the incoming message:

    * `{:flash, level, message}` — calls `put_flash/3` and returns
      `{:halt, socket}`.

    * `{action, subject}` — if a protocol implementation exists for the
      subject, delegates to `handle_info/3` on the subject's implementation.
      Otherwise returns `{:cont, socket}`.

    * `{action, subject, attrs}` — same as above but delegates to
      `handle_info/4` with the attrs.

  ## Examples

  Pipeline with Repo operations:

      %Post{}
      |> Post.changeset(attrs)
      |> Repo.insert()
      |> Amplified.PubSub.broadcast(:created)
      #=> {:ok, %Post{}} on success — broadcasts {:created, post}
      #=> {:error, %Changeset{}} on failure — no broadcast, passed through

  Message dispatching in a LiveView:

      def handle_info(message, socket) do
        case Amplified.PubSub.handle_info(message, socket) do
          {:cont, socket} -> {:noreply, socket}
          {:halt, socket} -> {:noreply, socket}
        end
      end
  '''

  use Amplified.PubSub, impl: true

  def broadcast({:ok, subject}, message), do: {:ok, PubSub.broadcast(subject, message)}
  def broadcast({n, list}, event) when is_list(list), do: {n, PubSub.broadcast(list, event)}
  def broadcast(error, _message), do: error
  def broadcast({:ok, subject}, event, attrs), do: {:ok, PubSub.broadcast(subject, event, attrs)}
  def broadcast(error, _message, _attrs), do: error
  def channel(tuple, _ns \\ nil), do: raise("No channel for #{inspect(tuple)}")
  def subscribe(tuple), do: raise("Cannot subscribe to #{inspect(tuple)}")
  def unsubscribe(tuple), do: raise("Cannot unsubscribe from #{inspect(tuple)}")

  def handle_info({:flash, level, message}, socket),
    do: {:halt, put_flash(socket, level, message)}

  def handle_info({action, subject}, socket) do
    if PubSub.impl_for(subject),
      do: PubSub.handle_info(subject, action, socket),
      else: {:cont, socket}
  end

  def handle_info({action, subject, changeset}, socket) do
    if PubSub.impl_for(subject),
      do: PubSub.handle_info(subject, action, changeset, socket),
      else: {:cont, socket}
  end

  def handle_info(_tuple, socket), do: {:cont, socket}
end
