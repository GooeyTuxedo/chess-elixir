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

  @impl true
  def handle_event("select_square", %{"file" => file, "rank" => rank}, socket) do
    position = {String.to_integer(file), String.to_integer(rank)}

    # TODO: Implement move logic
    {:noreply, assign(socket, selected_square: position)}
  end

  @impl true
  def handle_info({:player_joined, color, nickname}, socket) do
    # Refresh game state
    game_state = GameServer.get_state(socket.assigns.game_id)

    {:noreply, assign(socket,
      players: game_state.players,
      status: game_state.status
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-3xl font-bold mb-4">Chess Game</h1>

      <div class="mb-4">
        <div class="bg-gray-100 p-4 rounded">
          <h2 class="text-xl font-bold mb-2">Game Status: <%= display_status(@status) %></h2>
          <div class="flex justify-between">
            <div>
              <p>White: <%= display_player(@players.white) %></p>
            </div>
            <div>
              <p>Black: <%= display_player(@players.black) %></p>
            </div>
          </div>
          <p>You are playing as: <span class="font-bold"><%= display_color(@player_color) %></span></p>
        </div>
      </div>

      <div class="board-container">
        <div class="chess-board grid grid-cols-8 border border-gray-800 w-96 h-96">
          <%= for rank <- 7..0 do %>
            <%= for file <- 0..7 do %>
              <div class={"square #{square_color(file, rank)} #{selected_class({file, rank}, @selected_square)} w-12 h-12 flex items-center justify-center"}
                   phx-click="select_square"
                   phx-value-file={file}
                   phx-value-rank={rank}>
                <%= render_piece(@board.squares[{file, rank}]) %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp square_color(file, rank) do
    if rem(file + rank, 2) == 0, do: "bg-amber-200", else: "bg-amber-800"
  end

  defp selected_class(position, selected_position) do
    if position == selected_position, do: "ring-2 ring-blue-500", else: ""
  end

  defp render_piece(nil), do: ""
  defp render_piece({color, piece_type}) do
    unicode = case {color, piece_type} do
      {:white, :king} -> "♔"
      {:white, :queen} -> "♕"
      {:white, :rook} -> "♖"
      {:white, :bishop} -> "♗"
      {:white, :knight} -> "♘"
      {:white, :pawn} -> "♙"
      {:black, :king} -> "♚"
      {:black, :queen} -> "♛"
      {:black, :rook} -> "♜"
      {:black, :bishop} -> "♝"
      {:black, :knight} -> "♞"
      {:black, :pawn} -> "♟︎"
    end

    text_color = if color == :white, do: "text-white", else: "text-black"

    ~H"""
    <div class={"piece #{text_color} text-4xl"}>
      <%= unicode %>
    </div>
    """
  end

  defp display_status(:waiting_for_players), do: "Waiting for Players"
  defp display_status(:in_progress), do: "Game in Progress"
  defp display_status(:checkmate), do: "Checkmate"
  defp display_status(:draw), do: "Draw"

  defp display_player(nil), do: "Waiting for player..."
  defp display_player({_session_id, nickname}), do: nickname

  defp display_color(:white), do: "White"
  defp display_color(:black), do: "Black"
  defp display_color(:spectator), do: "Spectator"
end
