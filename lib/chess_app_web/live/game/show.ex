# lib/chess_app_web/live/game/show.ex
defmodule ChessAppWeb.GameLive.Show do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.GameServer

  @impl true
  def mount(%{"id" => game_id}, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChessApp.PubSub, "game:#{game_id}")
    end

    # Use session data
    player_session_id = session["player_session_id"]
    player_nickname = session["player_nickname"]

    # Attempt to join the game
    case GameServer.join_game(game_id, player_session_id, player_nickname) do
      {:ok, color} ->
        game_state = GameServer.get_state(game_id)

        {:ok, assign(socket,
          game_id: game_id,
          player_session_id: player_session_id,
          player_nickname: player_nickname,
          player_color: color,
          board: game_state.board,
          players: game_state.players,
          status: game_state.status,
          selected_square: nil,
          valid_moves: []
        )}

      {:error, :game_full} ->
        # Allow spectating
        game_state = GameServer.get_state(game_id)

        {:ok, assign(socket,
          game_id: game_id,
          player_session_id: player_session_id,
          player_nickname: player_nickname,
          player_color: :spectator,
          board: game_state.board,
          players: game_state.players,
          status: game_state.status,
          selected_square: nil,
          valid_moves: []
        )}
    end
  end

  # ... handle_event and handle_info implementations
end
