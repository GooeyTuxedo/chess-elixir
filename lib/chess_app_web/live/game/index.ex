defmodule ChessAppWeb.GameLive.Index do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.GameServer

  @impl true
  def mount(_params, session, socket) do
    socket = assign(socket,
      player_session_id: session["player_session_id"],
      player_nickname: session["player_nickname"]
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("create-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game()

    {:noreply, push_redirect(socket, to: Routes.game_show_path(socket, :show, game_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-3xl font-bold mb-4">Chess Game</h1>

      <div class="mb-4">
        <p>Playing as: <span class="font-bold"><%= @player_nickname %></span></p>
      </div>

      <div class="mb-4">
        <button phx-click="create-game" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
          Create New Game
        </button>
      </div>
    </div>
    """
  end
end
