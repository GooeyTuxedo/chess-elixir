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
        show_create_modal: false,
        show_ai_modal: false,
        ai_color: :black, # Default AI plays as black
        ai_difficulty: 2  # Default medium difficulty
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

  def handle_event("show-ai-modal", _params, socket) do
    {:noreply, assign(socket, show_ai_modal: true)}
  end

  def handle_event("hide-ai-modal", _params, socket) do
    {:noreply, assign(socket, show_ai_modal: false)}
  end

  def handle_event("set-ai-color", %{"color" => color}, socket) do
    {:noreply, assign(socket, ai_color: String.to_existing_atom(color))}
  end

  def handle_event("set-ai-difficulty", %{"difficulty" => difficulty}, socket) do
    {:noreply, assign(socket, ai_difficulty: String.to_integer(difficulty))}
  end

  def handle_event("create-ai-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game_with_ai(
      ai_color: socket.assigns.ai_color,
      ai_difficulty: socket.assigns.ai_difficulty
    )

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
