defmodule ChessAppWeb.GameLive.Show do
  use ChessAppWeb, :live_view
  alias ChessApp.Games.{GameServer, MoveValidator}

  @impl true
  def render(assigns) do
    ChessAppWeb.GameLive.ShowHTML.render(assigns)
  end

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

        # Apply defaults for potentially missing fields in existing games
        move_history = Map.get(game_state, :move_history, [])
        captured_pieces = Map.get(game_state, :captured_pieces, %{white: [], black: []})

        {:ok,
         assign(socket,
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
           promotion_selection: nil,
           move_history: move_history,
           captured_pieces: captured_pieces,
           page_title: "Chess Game"
         )}

      {:error, :game_full} ->
        # Allow spectating
        game_state = GameServer.get_state(game_id)

        # Apply defaults for potentially missing fields in existing games
        move_history = Map.get(game_state, :move_history, [])
        captured_pieces = Map.get(game_state, :captured_pieces, %{white: [], black: []})

        {:ok,
         assign(socket,
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
           promotion_selection: nil,
           move_history: move_history,
           captured_pieces: captured_pieces,
           page_title: "Chess Game"
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
                {:noreply,
                 assign(socket,
                   promotion_selection: %{from: selected, to: position}
                 )}
              else
                # Normal move
                make_move(socket, selected, position)
              end
            else
              # Normal move for non-pawn pieces
              make_move(socket, selected, position)
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
    make_move(socket, from, to, promotion_piece)
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    # Create a new game
    {:ok, new_game_id} = GameServer.create_game()

    # Redirect to the new game
    {:noreply, push_navigate(socket, to: ~p"/games/#{new_game_id}")}
  end

  @impl true
  def handle_info({:player_joined, _color, _nickname}, socket) do
    # Refresh game state
    game_state = GameServer.get_state(socket.assigns.game_id)

    {:noreply,
    assign(socket,
    players: game_state.players,
    status: game_state.status
    )}
  end

  @impl true
  def handle_info({:move_made, move, new_state}, socket) do
    # Determine if the turn changed to the current player
    turn_notification =
      if new_state.current_turn == socket.assigns.player_color do
        "Your turn to move!"
      else
        nil
      end

      # Apply defaults for potentially missing fields
      move_history = Map.get(new_state, :move_history, [])
      captured_pieces = Map.get(new_state, :captured_pieces, %{white: [], black: []})

      {:noreply,
      assign(socket,
      board: new_state.board,
      status: new_state.status,
      current_turn: new_state.current_turn,
      selected_square: nil,
      valid_moves: [],
      last_move: move,
      turn_notification: turn_notification,
      error_message: nil,
      move_history: move_history,
      captured_pieces: captured_pieces
      )}
    end

    @impl true
    def handle_info({:game_over, game_result, new_state}, socket) do
      # Apply defaults for potentially missing fields
      move_history = Map.get(new_state, :move_history, [])
      captured_pieces = Map.get(new_state, :captured_pieces, %{white: [], black: []})

      # Handle game end
      {:noreply,
      assign(socket,
      board: new_state.board,
      status: new_state.status,
      current_turn: new_state.current_turn,
      selected_square: nil,
      valid_moves: [],
      last_move: List.first(move_history),
      game_result: game_result,
      turn_notification: nil,
      error_message: nil,
      move_history: move_history,
      captured_pieces: captured_pieces
      )}
    end

    defp make_move(socket, from, to, promotion_piece \\ nil) do
      case GameServer.make_move(
             socket.assigns.game_id,
             socket.assigns.player_session_id,
             from,
             to,
             promotion_piece
           ) do
        {:ok, _} ->
          {:noreply, assign(socket,
            selected_square: nil,
            valid_moves: [],
            promotion_selection: nil  # Clear promotion selection after successful move
          )}

        {:error, :need_promotion_selection, from, to} ->
          # Show promotion selection UI
          {:noreply,
           assign(socket,
             promotion_selection: %{from: from, to: to}
           )}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             selected_square: nil,
             valid_moves: [],
             promotion_selection: nil,  # Clear promotion selection on error too
             error_message: "Invalid move: #{reason}"
           )}
      end
    end
end
