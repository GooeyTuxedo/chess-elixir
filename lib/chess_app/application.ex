defmodule ChessApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChessAppWeb.Telemetry,
      ChessApp.Repo,
      {DNSCluster, query: Application.get_env(:chess_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ChessApp.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ChessApp.Finch},
      # Start a worker by calling: ChessApp.Worker.start_link(arg)
      # {ChessApp.Worker, arg},
      # Start to serve requests, typically the last entry
      ChessAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
