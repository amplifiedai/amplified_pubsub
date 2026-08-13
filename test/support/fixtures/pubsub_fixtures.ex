defmodule Amplified.PubSubTest.Thing do
  @moduledoc false
  use Ecto.Schema
  use Amplified.PubSub

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "things" do
    field :name, :string
  end
end

defmodule Amplified.PubSubTest.Custom do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "customs" do
    field :name, :string
  end

  defimpl Amplified.PubSub.Protocol do
    use Amplified.PubSub, impl: true
    def channel(%{name: name}, _ns), do: "custom:#{name}"
  end
end

defmodule Amplified.PubSubTest.Handled do
  @moduledoc """
  A test struct with custom handle_info/3 and handle_info/4 implementations
  to verify that protocol dispatch calls schema-level handlers.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "handleds" do
    field :name, :string
  end

  use Amplified.PubSub do
    def handle_info(%Handled{} = handled, :updated, socket) do
      {:halt, Phoenix.Component.assign(socket, :handled, handled)}
    end

    def handle_info(%Handled{}, :updated, %{changed: changed}, socket) do
      {:halt, Phoenix.Component.assign(socket, :changed, changed)}
    end
  end
end

defmodule Amplified.PubSubTest.Recorder do
  @moduledoc """
  A test struct that records every `{id, event}` pair dispatched to it, in order, so a test can
  assert exactly which event reached which item rather than inferring it from a handler that
  matches only one event.

  A plain `defstruct` rather than an `Ecto.Schema` like its siblings. It needs nothing Ecto
  provides, and being the one fixture that isn't a schema, it is also what proves
  `use Amplified.PubSub` works on a bare struct — the protocol has no business requiring Ecto.
  """
  defstruct [:id]

  use Amplified.PubSub do
    def handle_info(%Recorder{id: id}, event, socket), do: record(socket, {id, event})

    def handle_info(%Recorder{id: id}, event, attrs, socket),
      do: record(socket, {id, event, attrs})

    defp record(socket, entry) do
      socket
      |> Map.fetch!(:assigns)
      |> Map.get(:seen, [])
      |> then(&{:cont, assign(socket, :seen, &1 ++ [entry])})
    end
  end
end

defmodule Amplified.PubSubTest.Partial do
  @moduledoc """
  A test struct that overrides `handle_info/3` for a single event and supplies no catch-all, which
  is the pitfall documented in `Amplified.PubSub`: the override replaces the injected default
  rather than adding a clause ahead of it, so any other event raises.

  It exists to hold that documented behaviour to account, and to show that the arities are
  independent — `handle_info/4` still falls through.
  """
  defstruct [:id]

  use Amplified.PubSub do
    def handle_info(%Partial{}, :updated, socket), do: {:halt, assign(socket, :hit, true)}
  end
end
