defmodule ChessApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      ChessApp.Repo,
      # Start the Telemetry supervisor
      ChessAppWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ChessApp.PubSub},
      # Start the game registry
      {Registry, keys: :unique, name: ChessApp.GameRegistry},
      # Start the dynamic supervisor for game servers
      {DynamicSupervisor, name: ChessApp.GameSupervisor, strategy: :one_for_one},
      # Start the game cleaner process
      ChessApp.Games.Cleaner,
      # Start the Endpoint (http/https)
      ChessAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChessApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChessAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
