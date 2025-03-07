defmodule ChessAppWeb.GameLive.ShowHTML do
  use ChessAppWeb, :html

  def render(assigns) do
    ~H"""
    <div class="game-container">
      <h1 class="game-title">Chess Game</h1>

      <div class="mb-6">
        <div class="flex justify-between">
          <div class={"player-card #{if @current_turn == :white, do: 'active'}"}>
            <div class="flex justify-between items-center">
              <div>
                <span class="text-xs">WHITE</span>
                <p class="mt-1 text-sm"><%= display_player(@players.white) %></p>
              </div>
              <%= if @current_turn == :white do %>
                <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
              <% end %>
            </div>
          </div>

          <div class={"player-card #{if @current_turn == :black, do: 'active'}"}>
            <div class="flex justify-between items-center">
              <div>
                <span class="text-xs">BLACK</span>
                <p class="mt-1 text-sm"><%= display_player(@players.black) %></p>
              </div>
              <%= if @current_turn == :black do %>
                <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-2 text-center text-sm">
          <p>You are playing as: <span class="text-purple-400 font-bold"><%= display_color(@player_color) %></span></p>

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
              <%= @error_message %>
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

      <div class="board-container mx-auto max-w-md">
        <div class="chess-board grid grid-cols-8 border-4 border-gray-800 w-96 h-96 mx-auto">
          <%= for rank <- if @player_color == :black, do: 0..7, else: 7..0 do %>
            <%= for file <- if @player_color == :black, do: 7..0, else: 0..7 do %>
              <div class={"square #{square_classes({file, rank}, @selected_square, @valid_moves, @last_move, @player_color == @current_turn)} w-12 h-12 flex items-center justify-center"}
                   phx-click="select_square"
                   phx-value-file={file}
                   phx-value-rank={rank}
                   data-file={file}
                   data-rank={rank}>
                <%= render_piece(@board.squares[{file, rank}], @status) %>

                <!-- Coordinate labels (optional) -->
                <div class="absolute text-xs opacity-30 bottom-0 right-1">
                  <%= if rank == (if @player_color == :black, do: 7, else: 0) do %>
                    <%= file_to_letter(file) %>
                  <% end %>
                  <%= if file == (if @player_color == :black, do: 0, else: 7) do %>
                    <%= rank + 1 %>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
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
              <%= game_result_title(@game_result) %>
            </h2>

            <p class="text-center mb-8 text-sm">
              <%= game_result_message(@game_result, @players) %>
            </p>

            <div class="flex justify-center space-x-4">
              <button
                class="game-button"
                phx-click="play_again">
                Play Again
              </button>

              <a
                href="/"
                class="game-button bg-gray-700 hover:bg-gray-600">
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
                  phx-value-piece={piece}>
                  <div class="text-4xl">
                    <%= promotion_piece_symbol(@player_color, piece) %>
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

  def square_color(file, rank) do
    if rem(file + rank, 2) == 0, do: "bg-amber-200", else: "bg-amber-800"
  end

  def render_piece(nil, _status), do: ""
  def render_piece({color, piece_type} = piece, status) do
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
