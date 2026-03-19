{:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: :amplified_pubsub_test)

ExUnit.start()
