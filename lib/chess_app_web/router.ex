defmodule ChessAppWeb.Router do
  use ChessAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ChessAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :ensure_player_session
  end

  pipeline :game do
    plug :put_root_layout, {ChessAppWeb.Layouts, :game}
  end

  defp ensure_player_session(conn, _opts) do
    ChessApp.Session.PlayerSession.ensure_player_session(conn)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChessAppWeb do
    pipe_through [:browser, :game]

    live "/", GameLive.Index, :index
    live "/games/new", GameLive.Index, :new
    live "/games/:id", GameLive.Show, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChessAppWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chess_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChessAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
