defmodule ChessAppWeb.GameLive.Index do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.GameServer

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign(socket,
        player_session_id: session["player_session_id"],
        player_nickname: session["player_nickname"],
        page_title: "Retro Chess"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("create-game", _params, socket) do
    {:ok, game_id} = GameServer.create_game()

    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end
end
