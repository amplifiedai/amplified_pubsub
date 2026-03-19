# Amplified.PubSub

A protocol-based PubSub abstraction for Phoenix LiveView.

```elixir
def create_post(attrs) do
  %Post{}
  |> Post.changeset(attrs)
  |> Repo.insert()
  |> PubSub.broadcast(:created)
end
```

`Amplified.PubSub` wraps `Phoenix.PubSub` with a protocol layer so the same
`broadcast/2`, `subscribe/1`, and `handle_info/2` calls work whether you pass
a struct, an `{:ok, struct}` tuple from a Repo operation, a list of structs,
or a raw channel string.

## Installation

Add `amplified_pubsub` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:amplified_pubsub, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure the PubSub server name used for subscriptions and broadcasts:

```elixir
# config/config.exs
config :amplified_pubsub, pubsub_server: :my_app
```

## Setup

Schema modules opt in with `use Amplified.PubSub`:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  use Amplified.PubSub

  schema "posts" do
    field :title, :string
    field :body, :string
    timestamps()
  end
end
```

This generates a protocol implementation that derives channels from the
module name and struct ID (`"post:abc-123"`), and provides default
`broadcast/2`, `subscribe/1`, and `handle_info/2` implementations.

## Broadcasting from context functions

`broadcast/2` returns its first argument and handles `{:ok, _}` / `{:error, _}`
tuples transparently, so it drops right into Ecto pipelines:

```elixir
defmodule MyApp.Blog do
  alias Amplified.PubSub

  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> PubSub.broadcast(:created)
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
    |> PubSub.broadcast(:updated)
  end

  def delete_post(%Post{} = post) do
    post
    |> Repo.delete()
    |> PubSub.broadcast(:deleted)
  end
end
```

## Lifecycle integration

For applications with many LiveViews, subscribe and attach the PubSub
dispatcher once as an `on_mount` hook:

```elixir
defmodule MyAppWeb.Hooks do
  import Phoenix.LiveView

  alias Amplified.PubSub

  defmodule Default do
    def on_mount(:default, _params, _session, socket) do
      {:cont, MyAppWeb.Hooks.attach_defaults(socket)}
    end
  end

  # This is the critical wiring step. attach_hook/4 registers
  # PubSub.handle_info/2 as a lifecycle hook that intercepts every
  # message the LiveView process receives. Without this, PubSub
  # messages will arrive but the protocol dispatch won't fire.
  def attach_defaults(socket) do
    socket
    |> subscribe()
    |> attach_hook(:pubsub, :handle_info, &PubSub.handle_info/2)
  end

  defp subscribe(socket) do
    if connected?(socket) do
      user = socket.assigns[:current_user]
      if user, do: PubSub.subscribe(user)
    end

    socket
  end
end
```

Then wire it up in the router:

```elixir
live_session :authenticated, on_mount: MyAppWeb.Hooks.Default do
  live "/posts", PostLive.Index
  live "/posts/:id", PostLive.Show
end
```

## Event handling in schemas

Handle PubSub events in the schema's own `use Amplified.PubSub` block:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  use Amplified.PubSub do
    def handle_info(%Post{id: id} = post, :updated, %{assigns: %{post: %{id: id}}} = socket) do
      {:cont, assign(socket, post: post)}
    end

    def handle_info(%Post{id: id}, :deleted, %{assigns: %{post: %{id: id}}} = socket) do
      {:halt, push_navigate(socket, to: ~p"/posts")}
    end
  end

  schema "posts" do
    field :title, :string
    field :body, :string
    timestamps()
  end
end
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/amplified_pubsub).

## Licence

MIT — see [LICENCE.md](LICENCE.md).
