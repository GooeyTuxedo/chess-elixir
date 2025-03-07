defmodule ChessAppWeb.GameLive.Show do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.{GameServer, MoveValidator}

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
          valid_moves: [],
          last_move: nil,
          error_message: nil
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
          valid_moves: [],
          last_move: nil,
          error_message: nil
        )}
    end
  end

  @impl true
  def handle_event("select_square", %{"file" => file, "rank" => rank}, socket) do
    position = {String.to_integer(file), String.to_integer(rank)}
    selected = socket.assigns.selected_square

    cond do
      # First selection - select a piece if it belongs to the player
      is_nil(selected) ->
        piece = socket.assigns.board.squares[position]
        if piece && elem(piece, 0) == socket.assigns.player_color do
          valid_moves = MoveValidator.valid_moves(socket.assigns.board, position)
          {:noreply, assign(socket, selected_square: position, valid_moves: valid_moves)}
        else
          {:noreply, socket}
        end

      # Second selection - try to move if the destination is valid
      true ->
        if position in socket.assigns.valid_moves do
          case GameServer.make_move(socket.assigns.game_id, socket.assigns.player_session_id, selected, position) do
            {:ok, _} ->
              {:noreply, assign(socket, selected_square: nil, valid_moves: [])}

            {:error, reason} ->
              {:noreply, assign(socket,
                selected_square: nil,
                valid_moves: [],
                error_message: "Invalid move: #{reason}"
              )}
          end
        else
          # Select a different piece of the same color
          piece = socket.assigns.board.squares[position]
          if piece && elem(piece, 0) == socket.assigns.player_color do
            valid_moves = MoveValidator.valid_moves(socket.assigns.board, position)
            {:noreply, assign(socket, selected_square: position, valid_moves: valid_moves)}
          else
            # Deselect if clicking elsewhere
            {:noreply, assign(socket, selected_square: nil, valid_moves: [])}
          end
        end
    end
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
  def handle_info({:move_made, move, new_state}, socket) do
    {:noreply, assign(socket,
      board: new_state.board,
      status: new_state.status,
      selected_square: nil,
      valid_moves: [],
      last_move: move
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

          <%= if @error_message do %>
            <div class="mt-2 text-red-500"><%= @error_message %></div>
          <% end %>
        </div>
      </div>

      <div class="board-container">
        <div class="chess-board grid grid-cols-8 border border-gray-800 w-96 h-96">
          <%= for rank <- 7..0 do %>
            <%= for file <- 0..7 do %>
              <div class={"square #{square_classes({file, rank}, @selected_square, @valid_moves, @last_move)} w-12 h-12 flex items-center justify-center"}
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

  defp square_classes(position, selected_position, valid_moves, last_move) do
    base_color = square_color(elem(position, 0), elem(position, 1))

    cond do
      position == selected_position ->
        "#{base_color} ring-2 ring-blue-500"

      position in valid_moves ->
        "#{base_color} ring-2 ring-green-500"

      last_move && (position == last_move.from || position == last_move.to) ->
        "#{base_color} ring-1 ring-yellow-500"

      true ->
        base_color
    end
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

    assigns = %{unicode: unicode, text_color: text_color}

    ~H"""
    <div class={"piece #{@text_color} text-4xl"}>
      <%= @unicode %>
    </div>
    """
  end

  defp display_status(:waiting_for_players), do: "Waiting for Players"
  defp display_status(:in_progress), do: "Game in Progress"
  defp display_status(:check_white), do: "White is in Check"
  defp display_status(:check_black), do: "Black is in Check"
  defp display_status(:checkmate_white), do: "Checkmate - Black Wins"
  defp display_status(:checkmate_black), do: "Checkmate - White Wins"
  defp display_status(:stalemate), do: "Draw - Stalemate"
  defp display_status(:draw_insufficient_material), do: "Draw - Insufficient Material"
  defp display_status(:draw_fifty_move_rule), do: "Draw - Fifty Move Rule"

  defp display_player(nil), do: "Waiting for player..."
  defp display_player({_session_id, nickname}), do: nickname

  defp display_color(:white), do: "White"
  defp display_color(:black), do: "Black"
  defp display_color(:spectator), do: "Spectator"
end
