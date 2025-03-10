defmodule ChessAppWeb.GameLive.Index do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.{GameServer, GameRegistry}

  @impl true
  def mount(_params, session, socket) do
    # Set up periodic refresh of game list
    if connected?(socket) do
      Process.send_after(self(), :refresh_games, 5000)
    end

    socket =
      assign(socket,
        player_session_id: session["player_session_id"],
        player_nickname: session["player_nickname"],
        page_title: "Retro Chess",
        joinable_games: GameRegistry.list_joinable_games(),
        spectatable_games: GameRegistry.list_spectatable_games(),
        completed_games: Enum.take(GameRegistry.list_completed_games(), 5), # Limit to 5 most recent
        show_create_modal: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("create-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game()

    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_event("show-create-modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: true)}
  end

  @impl true
  def handle_event("hide-create-modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false)}
  end

  @impl true
  def handle_event("create-private-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game(visibility: :private)
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_event("create-public-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game(visibility: :public)
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_info(:refresh_games, socket) do
    # Schedule next refresh
    Process.send_after(self(), :refresh_games, 5000)

    # Update game lists
    socket = assign(socket,
      joinable_games: GameRegistry.list_joinable_games(),
      spectatable_games: GameRegistry.list_spectatable_games(),
      completed_games: Enum.take(GameRegistry.list_completed_games(), 5)
    )

    {:noreply, socket}
  end
end
