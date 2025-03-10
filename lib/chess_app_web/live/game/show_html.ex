defmodule ChessAppWeb.GameLive.ShowHTML do
  use ChessAppWeb, :html

  def render(assigns) do
    ~H"""
    <div class="game-container">
      <h1 class="game-title">Chess Game</h1>

      <div class="mb-6">
        <div class="flex justify-between">
          <div class={"player-card #{if @current_turn == :white, do: ~s(active)}"}>
            <div class="flex justify-between items-center">
              <div>
                <span class="text-xs">WHITE</span>
                <p class="mt-1 text-sm">{display_player(@players.white)}</p>
              </div>
              <%= if @current_turn == :white do %>
                <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
              <% end %>
            </div>
          </div>

          <div class={"player-card #{if @current_turn == :black, do: ~s(active)}"}>
            <div class="flex justify-between items-center">
              <div>
                <span class="text-xs">BLACK</span>
                <p class="mt-1 text-sm">{display_player(@players.black)}</p>
              </div>
              <%= if @current_turn == :black do %>
                <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-2 text-center text-sm">
          <p>
            You are playing as:
            <span class="text-purple-400 font-bold">{display_color(@player_color)}</span>
          </p>

          <%= if @status == :waiting_for_players do %>
            <div class="game-notification mt-4">
              Waiting for opponent to join...
            </div>
          <% end %>

          <%= if @player_color == @current_turn && @status in [:in_progress, :check_white, :check_black] do %>
            <div class="game-notification mt-4">
              Your turn to move!
            </div>
          <% end %>

          <%= if @error_message do %>
            <div class="game-notification alert mt-4">
              {@error_message}
            </div>
          <% end %>

          <%= if @status == :check_white || @status == :check_black do %>
            <div class="game-notification alert mt-4">
              <%= if @status == :check_white do %>
                White is in check!
              <% else %>
                Black is in check!
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="game-flex-container">
        <!-- Left sidebar for captured pieces by white -->
        <div class="captured-pieces-container">
          <h3 class="text-sm mb-2 text-center border-b border-purple-800 pb-1">White Captures</h3>
          <div class="captured-pieces">
            <%= for {piece_color, piece_type} <- get_sorted_captures(@captured_pieces.white) do %>
              <div class="captured-piece">
                <div class={"piece text-white text-2xl"}>
                  {display_piece({piece_color, piece_type})}
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Chess board container -->
        <div class="board-container mx-auto">
          <div class="chess-board grid grid-cols-8 border-4 border-gray-800 w-96 h-96 mx-auto">
            <%= for rank <- if @player_color == :black, do: 0..7, else: 7..0//-1 do %>
              <%= for file <- if @player_color == :black, do: 7..0//-1, else: 0..7 do %>
                <div
                  class={"square #{square_classes({file, rank}, @selected_square, @valid_moves, @last_move, @player_color == @current_turn)} w-12 h-12 flex items-center justify-center"}
                  phx-click="select_square"
                  phx-value-file={file}
                  phx-value-rank={rank}
                  data-file={file}
                  data-rank={rank}
                >
                  {render_piece(@board.squares[{file, rank}], @status)}

                  <!-- Coordinate labels (optional) -->
                  <div class="absolute text-xs opacity-30 bottom-0 right-1">
                    <%= if rank == (if @player_color == :black, do: 7, else: 0) do %>
                      {file_to_letter(file)}
                    <% end %>
                    <%= if file == (if @player_color == :black, do: 0, else: 7) do %>
                      {rank + 1}
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Right sidebar for captured pieces by black -->
        <div class="captured-pieces-container">
          <h3 class="text-sm mb-2 text-center border-b border-purple-800 pb-1">Black Captures</h3>
          <div class="captured-pieces">
            <%= for {piece_color, piece_type} <- get_sorted_captures(@captured_pieces.black) do %>
              <div class="captured-piece">
                <div class={"piece text-black text-2xl"}>
                  {display_piece({piece_color, piece_type})}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Move history section below the board -->
      <div class="move-history-container mt-6">
        <h3 class="text-lg text-purple-400 mb-2 text-center">Move History</h3>

        <div class="move-history">
          <table class="w-full">
            <thead>
              <tr>
                <th class="px-2 text-left">#</th>
                <th class="px-2">White</th>
                <th class="px-2">Black</th>
              </tr>
            </thead>
            <tbody>
              <%= for {moves, index} <- get_paired_moves(@move_history) do %>
                <tr class="move-row">
                  <td class="px-2 text-gray-500"><%= index + 1 %>.</td>
                  <td class="px-2 text-center"><%= moves.white || "" %></td>
                  <td class="px-2 text-center"><%= moves.black || "" %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-6 flex justify-center">
        <a href="/" class="game-button mr-4">
          Back to Lobby
        </a>

        <%= if @status in [:checkmate_white, :checkmate_black, :stalemate, :draw_insufficient_material, :draw_fifty_move_rule] do %>
          <button phx-click="play_again" class="game-button">
            Play Again
          </button>
        <% end %>
      </div>

      <%= if @game_result do %>
        <div class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50">
          <div class="bg-gray-900 p-8 border-4 border-purple-700 rounded-lg shadow-lg max-w-md w-full font-pixel">
            <h2 class="text-xl mb-6 text-center text-purple-400">
              {game_result_title(@game_result)}
            </h2>

            <p class="text-center mb-8 text-sm">
              {game_result_message(@game_result, @players)}
            </p>

            <div class="flex justify-center space-x-4">
              <button class="game-button" phx-click="play_again">
                Play Again
              </button>

              <a href="/" class="game-button bg-gray-700 hover:bg-gray-600">
                Back to Lobby
              </a>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @promotion_selection do %>
        <div class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50">
          <div class="bg-gray-900 p-6 border-4 border-purple-700 rounded-lg shadow-lg font-pixel">
            <h3 class="text-lg mb-6 text-center text-purple-400">Choose Promotion</h3>

            <div class="flex space-x-4 justify-center">
              <%= for piece <- [:queen, :rook, :bishop, :knight] do %>
                <button
                  class="p-4 border-2 border-gray-600 rounded-lg hover:bg-gray-800 transition-all"
                  phx-click="promote"
                  phx-value-piece={piece}
                >
                  <div class="text-4xl">
                    {promotion_piece_symbol(@player_color, piece)}
                  </div>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def file_to_letter(file) do
    ["a", "b", "c", "d", "e", "f", "g", "h"]
    |> Enum.at(file)
  end

  def square_classes(position, selected_position, valid_moves, last_move, is_player_turn) do
    base_color = square_color(elem(position, 0), elem(position, 1))

    modified_color = if !is_player_turn do
      # Add a subtle gray overlay when it's not the player's turn
      "#{base_color} opacity-80"
    else
      base_color
    end

    cond do
      position == selected_position ->
        "#{modified_color} ring-2 ring-blue-500"

      position in valid_moves ->
        "#{modified_color} ring-2 ring-green-500"

      last_move && (position == last_move.from || position == last_move.to) ->
        "#{modified_color} ring-1 ring-yellow-500"

      true ->
        modified_color
    end
  end

  def square_color(file, rank) do
    if rem(file + rank, 2) == 0, do: "bg-amber-200", else: "bg-amber-800"
  end

  def render_piece(nil, _status), do: ""

  def render_piece({color, piece_type} = piece, status) do
    unicode =
      case {color, piece_type} do
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
    check_highlight =
      case {piece, status} do
        {{:white, :king}, :check_white} -> "bg-red-500 rounded-full"
        {{:black, :king}, :check_black} -> "bg-red-500 rounded-full"
        _ -> ""
      end

    assigns = %{unicode: unicode, text_color: text_color, check_highlight: check_highlight}

    ~H"""
    <div class={"piece #{@text_color} #{@check_highlight} text-4xl"}>
      {@unicode}
    </div>
    """
  end

  def display_status(:waiting_for_players), do: "Waiting for Players"
  def display_status(:in_progress), do: "Game in Progress"
  def display_status(:check_white), do: "White is in Check"
  def display_status(:check_black), do: "Black is in Check"
  def display_status(:checkmate_white), do: "Checkmate - Black Wins"
  def display_status(:checkmate_black), do: "Checkmate - White Wins"
  def display_status(:stalemate), do: "Draw - Stalemate"
  def display_status(:draw_insufficient_material), do: "Draw - Insufficient Material"
  def display_status(:draw_fifty_move_rule), do: "Draw - Fifty Move Rule"

  def display_player(nil), do: "Waiting for player..."
  def display_player({_session_id, nickname}), do: nickname

  def display_color(:white), do: "White"
  def display_color(:black), do: "Black"
  def display_color(:spectator), do: "Spectator"

  def game_result_title(game_result) do
    case game_result do
      %{winner: nil} -> "Game Drawn"
      %{winner: _} -> "Checkmate!"
    end
  end

  def game_result_message(game_result, players) do
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

  def player_nickname({_session_id, nickname}), do: nickname

  def promotion_piece_symbol(color, piece_type) do
    unicode =
      case {color, piece_type} do
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
      {@unicode}
    </div>
    """
  end

  def get_paired_moves(nil), do: []
  def get_paired_moves(move_history) when is_list(move_history) do
    # Reverse the move history to get chronological order
    moves = Enum.reverse(move_history)

    # Check for notation field in moves
    if moves != [] and not Map.has_key?(List.first(moves), :notation) do
      # If no notation is available, return empty result
      []
    else
      # Group moves into pairs (white's move and black's response)
      moves
      |> Enum.reduce({[], nil, 0}, fn move, {pairs, current_white, move_number} ->
        notation = Map.get(move, :notation, "")

        if move.player_color == :white do
          # Start a new pair with white's move
          {pairs, %{white: notation, black: nil}, move_number + 1}
        else
          # Complete the current pair with black's move
          pair = %{white: current_white[:white], black: notation}
          {[pair | pairs], nil, move_number}
        end
      end)
      |> then(fn {pairs, current_white, move_number} ->
        # Add the last white move if there's no black response yet
        pairs = if current_white do
          [current_white | pairs]
        else
          pairs
        end

        # Return pairs with their move numbers
        pairs |> Enum.reverse() |> Enum.with_index()
      end)
    end
  end
  def get_paired_moves(_), do: []

  def get_sorted_captures(nil), do: []
  def get_sorted_captures(captured_pieces) when is_list(captured_pieces) do
    # Sort captured pieces by value (most valuable first)
    captured_pieces
    |> Enum.sort_by(fn {_color, piece_type} ->
      case piece_type do
        :queen -> 1
        :rook -> 2
        :bishop -> 3
        :knight -> 4
        :pawn -> 5
        _ -> 6
      end
    end)
  end
  def get_sorted_captures(_), do: []

  def display_piece({_color, piece_type}) do
    case piece_type do
      :queen -> "♛"
      :rook -> "♜"
      :bishop -> "♝"
      :knight -> "♞"
      :pawn -> "♟︎"
      :king -> "♚"
      _ -> "?"
    end
  end
end
