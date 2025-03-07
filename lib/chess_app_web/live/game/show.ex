# lib/chess_app_web/live/game/show.ex
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
          current_turn: game_state.current_turn,
          selected_square: nil,
          valid_moves: [],
          last_move: nil,
          error_message: nil,
          turn_notification: nil,
          game_result: game_state.game_result,
          promotion_selection: nil
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
          current_turn: game_state.current_turn,
          selected_square: nil,
          valid_moves: [],
          last_move: nil,
          error_message: nil,
          turn_notification: nil,
          game_result: game_state.game_result,
          promotion_selection: nil
        )}
    end
  end

  @impl true
  def handle_event("select_square", %{"file" => file, "rank" => rank}, socket) do
    # Only allow moves if it's the player's turn and game is in progress
    if socket.assigns.player_color == socket.assigns.current_turn &&
       socket.assigns.status in [:in_progress, :check_white, :check_black] do
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
            # Check for potential pawn promotion
            piece = socket.assigns.board.squares[selected]
            if piece && elem(piece, 1) == :pawn do
              {_, piece_color} = piece
              last_rank = if piece_color == :white, do: 7, else: 0

              if elem(position, 1) == last_rank do
                # Show promotion dialog instead of completing the move
                {:noreply, assign(socket,
                  promotion_selection: %{from: selected, to: position}
                )}
              else
                # Normal move
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
              end
            else
              # Normal move for non-pawn pieces
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
    else
      # Not this player's turn or game not in progress
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("promote", %{"piece" => piece}, socket) do
    from = socket.assigns.promotion_selection.from
    to = socket.assigns.promotion_selection.to

    # Convert piece string to atom
    promotion_piece = String.to_existing_atom(piece)

    # Complete the move with the promotion
    case GameServer.make_move(
      socket.assigns.game_id,
      socket.assigns.player_session_id,
      from,
      to,
      promotion_piece
    ) do
      {:ok, _} ->
        {:noreply, assign(socket,
          promotion_selection: nil,
          selected_square: nil,
          valid_moves: []
        )}

      {:error, reason} ->
        {:noreply, assign(socket,
          promotion_selection: nil,
          selected_square: nil,
          valid_moves: [],
          error_message: "Invalid promotion: #{reason}"
        )}
    end
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    # Create a new game
    {:ok, new_game_id} = GameServer.create_game()

    # Redirect to the new game
    {:noreply, push_redirect(socket, to: Routes.game_show_path(socket, :show, new_game_id))}
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
    # Determine if the turn changed to the current player
    turn_notification = if new_state.current_turn == socket.assigns.player_color do
      "Your turn to move!"
    else
      nil
    end

    {:noreply, assign(socket,
      board: new_state.board,
      status: new_state.status,
      current_turn: new_state.current_turn,
      selected_square: nil,
      valid_moves: [],
      last_move: move,
      turn_notification: turn_notification,
      error_message: nil
    )}
  end

  @impl true
  def handle_info({:game_over, game_result, new_state}, socket) do
    # Handle game end
    {:noreply, assign(socket,
      board: new_state.board,
      status: new_state.status,
      current_turn: new_state.current_turn,
      selected_square: nil,
      valid_moves: [],
      last_move: List.first(new_state.move_history),
      game_result: game_result,
      turn_notification: nil,
      error_message: nil
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
            <div class={"p-2 #{turn_highlight_class(:white, @current_turn)}"}>
              <p>White: <%= display_player(@players.white) %></p>
              <%= if @current_turn == :white do %>
                <span class="text-sm font-semibold">Current Turn</span>
              <% end %>
            </div>
            <div class={"p-2 #{turn_highlight_class(:black, @current_turn)}"}>
              <p>Black: <%= display_player(@players.black) %></p>
              <%= if @current_turn == :black do %>
                <span class="text-sm font-semibold">Current Turn</span>
              <% end %>
            </div>
          </div>

          <p class="mt-2">You are playing as: <span class="font-bold"><%= display_color(@player_color) %></span></p>

          <%= if @player_color == @current_turn && @status in [:in_progress, :check_white, :check_black] do %>
            <p class="mt-2 text-green-600 font-bold">Your turn!</p>
          <% end %>

          <%= if @error_message do %>
            <div class="mt-2 text-red-500"><%= @error_message %></div>
          <% end %>
        </div>
      </div>

      <%= if @turn_notification do %>
        <div class="mt-4 p-3 bg-green-100 text-green-800 rounded-lg text-center animate-pulse">
          <%= @turn_notification %>
        </div>
      <% end %>

      <%= if @status == :check_white || @status == :check_black do %>
        <div class="mt-4 p-3 bg-red-100 text-red-800 rounded-lg text-center animate-pulse">
          <%= if @status == :check_white do %>
            <strong>White is in check!</strong>
          <% else %>
            <strong>Black is in check!</strong>
          <% end %>

          <%= if @player_color == :white && @status == :check_white ||
                @player_color == :black && @status == :check_black do %>
            <p class="mt-1">You must move out of check!</p>
          <% end %>
        </div>
      <% end %>

      <div class={[
        "mt-4 p-3 rounded-lg text-center",
        (if @player_color == @current_turn, do: "bg-green-100", else: "bg-gray-100")
      ]}>
        <h3 class="font-bold">
          <%= if @player_color == @current_turn do %>
            Your Turn to Move
          <% else %>
            Waiting for <%= display_color(@current_turn) %> to Move
          <% end %>
        </h3>
      </div>

      <div class="board-container mt-4">
        <div class="chess-board grid grid-cols-8 border border-gray-800 w-96 h-96">
          <%= for rank <- 7..0 do %>
            <%= for file <- 0..7 do %>
              <div class={"square #{square_classes({file, rank}, @selected_square, @valid_moves, @last_move, @player_color == @current_turn)} w-12 h-12 flex items-center justify-center"}
                   phx-click="select_square"
                   phx-value-file={file}
                   phx-value-rank={rank}>
                <%= render_piece(@board.squares[{file, rank}], @status) %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%= if @game_result do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white p-8 rounded-lg shadow-lg max-w-md w-full">
            <h2 class="text-2xl font-bold mb-4 text-center">
              <%= game_result_title(@game_result) %>
            </h2>

            <p class="text-center mb-6">
              <%= game_result_message(@game_result, @players) %>
            </p>

            <div class="flex justify-center space-x-4">
              <button
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
                phx-click="play_again">
                Play Again
              </button>

              <a
                href="/"
                class="px-4 py-2 bg-gray-300 text-gray-800 rounded hover:bg-gray-400">
                Back to Lobby
              </a>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @promotion_selection do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white p-6 rounded-lg shadow-lg">
            <h3 class="text-xl font-bold mb-4 text-center">Choose Promotion Piece</h3>

            <div class="flex space-x-4 justify-center">
              <%= for piece <- [:queen, :rook, :bishop, :knight] do %>
                <button
                  class="p-2 border border-gray-300 rounded hover:bg-gray-100"
                  phx-click="promote"
                  phx-value-piece={piece}>
                  <%= promotion_piece_symbol(@player_color, piece) %>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp square_color(file, rank) do
    if rem(file + rank, 2) == 0, do: "bg-amber-200", else: "bg-amber-800"
  end

  defp square_classes(position, selected_position, valid_moves, last_move, is_player_turn) do
    base_color = square_color(elem(position, 0), elem(position, 1))

    if !is_player_turn do
      # Add a subtle gray overlay when it's not the player's turn
      base_color = "#{base_color} opacity-80"
    end

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

  defp render_piece(nil, _status), do: ""
  defp render_piece({color, piece_type} = piece, status) do
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

    # Add a background highlight for kings in check
    check_highlight = case {piece, status} do
      {{:white, :king}, :check_white} -> "bg-red-500 rounded-full"
      {{:black, :king}, :check_black} -> "bg-red-500 rounded-full"
      _ -> ""
    end

    assigns = %{unicode: unicode, text_color: text_color, check_highlight: check_highlight}

    ~H"""
    <div class={"piece #{@text_color} #{@check_highlight} text-4xl"}>
      <%= @unicode %>
    </div>
    """
  end

  defp turn_highlight_class(player_color, current_turn) do
    if player_color == current_turn, do: "bg-yellow-100 rounded", else: ""
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

  defp game_result_title(game_result) do
    case game_result do
      %{winner: nil} -> "Game Drawn"
      %{winner: _} -> "Checkmate!"
    end
  end

  defp game_result_message(game_result, players) do
    case game_result do
      %{winner: :white, reason: :checkmate} ->
        "White (#{player_nickname(players.white)}) wins by checkmate!"

      %{winner: :black, reason: :checkmate} ->
        "Black (#{player_nickname(players.black)}) wins by checkmate!"

      %{winner: nil, reason: :stalemate} ->
        "Draw by stalemate - no legal moves available."

      %{winner: nil, reason: :insufficient_material} ->
        "Draw by insufficient material - neither player can checkmate."

      %{winner: nil, reason: :fifty_move_rule} ->
        "Draw by fifty-move rule - no captures or pawn moves in the last 50 moves."
    end
  end

  defp player_nickname({_session_id, nickname}), do: nickname

  defp promotion_piece_symbol(color, piece_type) do
    unicode = case {color, piece_type} do
      {:white, :queen} -> "♕"
      {:white, :rook} -> "♖"
      {:white, :bishop} -> "♗"
      {:white, :knight} -> "♘"
      {:black, :queen} -> "♛"
      {:black, :rook} -> "♜"
      {:black, :bishop} -> "♝"
      {:black, :knight} -> "♞"
    end

    assigns = %{unicode: unicode}

    ~H"""
    <div class="text-4xl">
      <%= @unicode %>
    </div>
    """
  end
end
