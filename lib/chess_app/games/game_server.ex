defmodule ChessApp.Games.GameServer do
  use GenServer
  alias ChessApp.Games.{Board, MoveValidator, ChessNotation, AIPlayer}

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    created_at = Keyword.get(opts, :created_at, DateTime.utc_now())

    # Add metadata when starting the process
    opts = Keyword.put(opts, :created_at, created_at)

    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  def create_game(opts \\ []) do
    game_id = Keyword.get(opts, :game_id, generate_game_id())
    visibility = Keyword.get(opts, :visibility, :public)
    created_at = DateTime.utc_now()
    ai_player = Keyword.get(opts, :ai_player)
    ai_difficulty = Keyword.get(opts, :ai_difficulty, 2)

    game_opts = [
      game_id: game_id,
      visibility: visibility,
      created_at: created_at,
      ai_player: ai_player,
      ai_difficulty: ai_difficulty
    ]

    case DynamicSupervisor.start_child(
      ChessApp.GameSupervisor,
      {__MODULE__, game_opts}
    ) do
      {:ok, _pid} ->
        {:ok, game_id}
      error -> error
    end
  end

  def create_game_with_ai(opts \\ []) do
    game_id = Keyword.get(opts, :game_id, generate_game_id())
    visibility = Keyword.get(opts, :visibility, :public)
    ai_color = Keyword.get(opts, :ai_color, :black)
    ai_difficulty = Keyword.get(opts, :ai_difficulty, 1)

    # Create a new game
    {:ok, game_id} = create_game([
      game_id: game_id,
      visibility: visibility
    ])

    # Get the game pid
    pid = GenServer.whereis(via_tuple(game_id))

    # Manually set up AI player in the game state
    :sys.replace_state(pid, fn state ->
      # Create AI nickname based on difficulty
      ai_nickname = case ai_difficulty do
        3 -> "AI (Hard)"
        2 -> "AI (Medium)"
        _ -> "AI (Easy)"
      end

      # Update the state
      %{state |
        ai_player: ai_color,
        ai_difficulty: ai_difficulty
      }
    end)

    # Return the game ID
    {:ok, game_id}
  end

  def join_game(game_id, player_session_id, player_nickname) do
    GenServer.call(via_tuple(game_id), {:join_game, player_session_id, player_nickname})
  end

  def make_move(game_id, player_session_id, from, to, promotion_piece \\ nil) do
    GenServer.call(via_tuple(game_id), {:make_move, player_session_id, from, to, promotion_piece})
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  def ping(game_id) do
    try do
      GenServer.call(via_tuple(game_id), :ping)
    rescue
      _ -> {:error, :game_not_found}
    end
  end

  def terminate_game(game_id) do
    # Find the actual PID from the registry
    case Registry.lookup(ChessApp.GameRegistry, game_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(ChessApp.GameSupervisor, pid)
      _ ->
        {:error, :game_not_found}
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    visibility = Keyword.get(opts, :visibility, :public)
    created_at = Keyword.get(opts, :created_at, DateTime.utc_now())
    ai_player = Keyword.get(opts, :ai_player)
    ai_difficulty = Keyword.get(opts, :ai_difficulty, 2)

    # Store the created_at in the process dictionary for the GameRegistry
    Process.put(:created_at, created_at)

    {:ok,
     %{
       game_id: game_id,
       visibility: visibility,
       created_at: created_at,
       last_activity: created_at,
       board: Board.new(),
       players: %{
         white: nil,
         black: nil
       },
       status: :waiting_for_players,
       move_history: [],
       captured_pieces: %{
         white: [],
         black: []
       },
       game_result: nil,
       ai_player: ai_player,
       ai_difficulty: ai_difficulty
     }}
  end

  @impl true
  def handle_call({:join_game, player_session_id, player_nickname}, _from, state) do
    # Check if player is already in the game
    player_color = get_player_color(state, player_session_id)

    if player_color do
      # Player already joined, return their color
      {:reply, {:ok, player_color}, state}
    else
      # If AI is playing, ensure the player can only join as the human color
      available_color = case state.ai_player do
        :white -> :black
        :black -> :white
        nil -> if is_nil(state.players.white), do: :white, else: :black
      end

      # Check if the available color is already taken
      if (available_color == :white && state.players.white) ||
         (available_color == :black && state.players.black) do
        {:reply, {:error, :game_full}, state}
      else
        # Assign player to available color
        players = Map.put(state.players, available_color, {player_session_id, player_nickname})

        # If this is an AI game, assign the AI player too
        players = if state.ai_player do
          ai_nickname = case state.ai_difficulty do
            3 -> "AI (Hard)"
            2 -> "AI (Medium)"
            _ -> "AI (Easy)"
          end

          Map.put(players, state.ai_player, {"ai_session", ai_nickname})
        else
          players
        end

        # Check if game can now start
        status = if players.white && players.black, do: :in_progress, else: :waiting_for_players

        # Update state
        state = %{
          state |
          players: players,
          status: status,
          last_activity: DateTime.utc_now()
        }

        # Broadcast new player
        Phoenix.PubSub.broadcast(
          ChessApp.PubSub,
          "game:#{state.game_id}",
          {:player_joined, available_color, player_nickname}
        )

        # If the AI should move first, schedule the move
        if status == :in_progress && state.ai_player == :white do
          Process.send_after(self(), :ai_move, 1000)
        end

        {:reply, {:ok, available_color}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Add current_turn to the state map that gets returned
    game_info = %{
      game_id: state.game_id,
      board: state.board,
      players: state.players,
      status: state.status,
      visibility: state.visibility,
      created_at: state.created_at,
      last_activity: state.last_activity,
      current_turn: state.board.turn,
      move_history: state.move_history,
      game_result: state.game_result
    }

    {:reply, game_info, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    # Update the last activity timestamp
    new_state = %{state | last_activity: DateTime.utc_now()}
    {:reply, :pong, new_state}
  end

  @impl true
  def handle_call({:make_move, player_session_id, from, to, promotion_piece}, _from, state) do
    player_color = get_player_color(state, player_session_id)

    # Check if it's a valid player and it's their turn
    if player_color && player_color == state.board.turn do
      # Validate promotion piece if provided
      if promotion_piece != nil && promotion_piece not in [:queen, :rook, :bishop, :knight] do
        {:reply, {:error, :invalid_promotion_piece}, state}
      else
        # Validate the move
        case MoveValidator.validate_move(state.board, from, to, player_color) do
          {:ok, :promotion} when promotion_piece != nil ->
            # Execute promotion move
            case Board.make_move(state.board, from, to, :promotion, promotion_piece) do
              {:ok, new_board} ->
                # Record the move
                move = %{
                  from: from,
                  to: to,
                  piece: Board.piece_at(state.board, from),
                  move_type: :promotion,
                  promotion_piece: promotion_piece,
                  player_color: player_color,
                  timestamp: DateTime.utc_now()
                }

                # Handle rest of move similar to other moves
                handle_move_result(state, new_board, move)

              error ->
                {:reply, error, state}
            end

          {:ok, :promotion} ->
            # Promotion piece is required but not provided
            # Return a special error that the LiveView will handle by showing promotion options
            {:reply, {:error, :need_promotion_selection, from, to}, state}

          {:ok, move_type} ->
            # Execute the standard move
            case Board.make_move(state.board, from, to, move_type) do
              {:ok, new_board} ->
                # Record the move
                move = %{
                  from: from,
                  to: to,
                  piece: Board.piece_at(state.board, from),
                  move_type: move_type,
                  player_color: player_color,
                  timestamp: DateTime.utc_now()
                }

                handle_move_result(state, new_board, move)

              error ->
                {:reply, error, state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      end
    else
      reason =
        cond do
          !player_color -> :not_a_player
          player_color != state.board.turn -> :not_your_turn
          true -> :unknown_error
        end

      {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:ai_move, state) do
    if state.status in [:in_progress, :check_white, :check_black] && state.board.turn == state.ai_player do
      # Select the best move for the AI
      {from, to, promotion_piece} = AIPlayer.select_move(state.board, state.ai_player, state.ai_difficulty)

      # Make the AI move
      case make_ai_move(state, from, to, promotion_piece) do
        {:ok, new_state} ->
          {:noreply, new_state}
        {:error, _reason} ->
          # If the AI somehow selected an invalid move, try again with a random move
          all_moves = generate_random_move(state.board, state.ai_player)
          {from, to, promotion_piece} = Enum.random(all_moves)
          {:ok, new_state} = make_ai_move(state, from, to, promotion_piece)
          {:noreply, new_state}
      end
    else
      {:noreply, state}
    end
  end

  defp handle_move_result(state, new_board, move) do
    # Check for game end conditions
    game_status = check_game_status(new_board)

    # Determine if the move resulted in check or checkmate
    is_check = game_status in [:check_white, :check_black]
    is_checkmate = game_status in [:checkmate_white, :checkmate_black]

    # Generate algebraic notation for the move if ChessNotation module exists
    notation = if Code.ensure_loaded?(ChessApp.Games.ChessNotation) do
      ChessApp.Games.ChessNotation.to_algebraic_notation(move, state.board, is_check, is_checkmate)
    else
      nil
    end

    # Track captured pieces if the field exists in the state
    captured_pieces = if Map.has_key?(state, :captured_pieces) do
      update_captured_pieces(state.captured_pieces, state.board, move)
    else
      %{white: [], black: []}
    end

    # Add notation to the move if notation was generated
    move_with_notation = if notation, do: Map.put(move, :notation, notation), else: move

    # Determine game result if the game has ended
    game_result =
      case game_status do
        :checkmate_white -> %{winner: :black, reason: :checkmate}
        :checkmate_black -> %{winner: :white, reason: :checkmate}
        :stalemate -> %{winner: nil, reason: :stalemate}
        :draw_insufficient_material -> %{winner: nil, reason: :insufficient_material}
        :draw_fifty_move_rule -> %{winner: nil, reason: :fifty_move_rule}
        _ -> nil
      end

    # Update state with current timestamp and conditionally add new fields
    current_time = DateTime.utc_now()

    new_state = state
      |> Map.put(:board, new_board)
      |> Map.put(:status, game_status)
      |> Map.put(:move_history, [move_with_notation | state.move_history])
      |> Map.put(:game_result, game_result)
      |> Map.put(:last_activity, current_time)

    # Only add captured_pieces if it previously existed
    new_state = if Map.has_key?(state, :captured_pieces) do
      Map.put(new_state, :captured_pieces, captured_pieces)
    else
      new_state
    end

    # Broadcast the move and game result if the game ended
    broadcast_state = Map.put(new_state, :current_turn, new_board.turn)

    if game_result do
      Phoenix.PubSub.broadcast(
        ChessApp.PubSub,
        "game:#{state.game_id}",
        {:game_over, game_result, broadcast_state}
      )
    else
      Phoenix.PubSub.broadcast(
        ChessApp.PubSub,
        "game:#{state.game_id}",
        {:move_made, move_with_notation, broadcast_state}
      )
    end

    # Schedule AI move if it's the AI's turn after this move
    new_state = if state.ai_player == new_board.turn do
      # Schedule the AI to make a move after a short delay
      Process.send_after(self(), :ai_move, 1000)
      new_state
    else
      new_state
    end

    {:reply, {:ok, move.move_type}, new_state}
  end

  # Helper function to make AI moves
  defp make_ai_move(state, from, to, promotion_piece) do
    # Get the piece color before making the move
    piece = Board.piece_at(state.board, from)
    _piece_color = elem(piece, 0)

    # Determine move type
    move_type = case MoveValidator.validate_move(state.board, from, to, state.ai_player) do
      {:ok, type} -> type
      {:error, _} -> :normal  # Fallback
    end

    # Make the move, ensuring promotion maintains the correct color
    case Board.make_move(state.board, from, to, move_type, promotion_piece) do
      {:ok, new_board} ->        # Record the move
        move = %{
          from: from,
          to: to,
          piece: Board.piece_at(state.board, from),
          move_type: move_type,
          promotion_piece: promotion_piece,
          player_color: state.ai_player,
          timestamp: DateTime.utc_now()
        }

        # Check for game end conditions
        game_status = check_game_status(new_board)

        # Add notation to the move
        notation = ChessApp.Games.ChessNotation.to_algebraic_notation(
          move,
          state.board,
          game_status in [:check_white, :check_black],
          game_status in [:checkmate_white, :checkmate_black]
        )

        move_with_notation = Map.put(move, :notation, notation)

        # Update captured pieces
        captured_pieces = update_captured_pieces(state.captured_pieces, state.board, move)

        # Determine game result
        game_result = case game_status do
          :checkmate_white -> %{winner: :black, reason: :checkmate}
          :checkmate_black -> %{winner: :white, reason: :checkmate}
          :stalemate -> %{winner: nil, reason: :stalemate}
          :draw_insufficient_material -> %{winner: nil, reason: :insufficient_material}
          :draw_fifty_move_rule -> %{winner: nil, reason: :fifty_move_rule}
          _ -> nil
        end

        # Update state
        new_state = state
          |> Map.put(:board, new_board)
          |> Map.put(:status, game_status)
          |> Map.put(:move_history, [move_with_notation | state.move_history])
          |> Map.put(:game_result, game_result)
          |> Map.put(:last_activity, DateTime.utc_now())
          |> Map.put(:captured_pieces, captured_pieces)

        # Broadcast the move
        broadcast_state = Map.put(new_state, :current_turn, new_board.turn)

        if game_result do
          Phoenix.PubSub.broadcast(
            ChessApp.PubSub,
            "game:#{state.game_id}",
            {:game_over, game_result, broadcast_state}
          )
        else
          Phoenix.PubSub.broadcast(
            ChessApp.PubSub,
            "game:#{state.game_id}",
            {:move_made, move_with_notation, broadcast_state}
          )
        end

        {:ok, new_state}

      error ->
        error
    end
  end

  # Helper to generate a random valid move
  defp generate_random_move(board, color) do
    board.squares
    |> Enum.filter(fn {{_file, _rank}, {piece_color, _}} -> piece_color == color end)
    |> Enum.flat_map(fn {from, _piece} ->
      # Get all valid destinations for this piece
      board
      |> MoveValidator.valid_moves(from)
      |> Enum.map(fn to ->
        # Check if this is a pawn promotion move
        promotion_piece = needs_promotion?(board, from, to)
        {from, to, promotion_piece}
      end)
    end)
  end

  # Helper to check if a move results in promotion
  defp needs_promotion?(board, from, to) do
    piece = Board.piece_at(board, from)

    case piece do
      {:white, :pawn} ->
        {_, to_rank} = to
        if to_rank == 7, do: :queen, else: nil

      {:black, :pawn} ->
        {_, to_rank} = to
        if to_rank == 0, do: :queen, else: nil

      _ ->
        nil
    end
  end

  defp update_captured_pieces(captured_pieces, board, move) do
    case move.move_type do
      :capture ->
        # A standard capture - find what piece was captured
        captured = board.squares[move.to]
        if captured do
          # Add to the list of pieces captured by the player who made the move
          Map.update!(captured_pieces, move.player_color, fn pieces -> [captured | pieces] end)
        else
          captured_pieces
        end

      :en_passant ->
        # En passant capture - we need to get the pawn at the special position
        {to_file, to_rank} = move.to
        captured_rank = if move.player_color == :white, do: to_rank - 1, else: to_rank + 1
        captured_position = {to_file, captured_rank}
        captured = board.squares[captured_position]

        if captured do
          Map.update!(captured_pieces, move.player_color, fn pieces -> [captured | pieces] end)
        else
          captured_pieces
        end

      _ ->
        # No capture occurred
        captured_pieces
    end
  end

  defp via_tuple(game_id) do
    {:via, Registry, {ChessApp.GameRegistry, game_id}}
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp get_player_color(state, player_session_id) do
    cond do
      match?({^player_session_id, _}, state.players.white) -> :white
      match?({^player_session_id, _}, state.players.black) -> :black
      true -> nil
    end
  end

  defp check_game_status(board) do
    white_king_pos = find_king(board, :white)
    black_king_pos = find_king(board, :black)

    white_in_check = is_in_check?(board, white_king_pos, :white)
    black_in_check = is_in_check?(board, black_king_pos, :black)

    current_player = board.turn

    cond do
      # Checkmate - current player has no legal moves and is in check
      (current_player == :white && white_in_check && has_no_legal_moves?(board, :white)) ||
          (current_player == :black && black_in_check && has_no_legal_moves?(board, :black)) ->
        if current_player == :white, do: :checkmate_white, else: :checkmate_black

      # Stalemate - current player has no legal moves and is not in check
      has_no_legal_moves?(board, current_player) &&
          ((current_player == :white && !white_in_check) ||
             (current_player == :black && !black_in_check)) ->
        :stalemate

      # Check - king is under attack
      white_in_check ->
        :check_white

      black_in_check ->
        :check_black

      # Insufficient material
      is_draw_by_insufficient_material?(board) ->
        :draw_insufficient_material

      # Fifty-move rule
      board.halfmove_clock >= 100 ->
        :draw_fifty_move_rule

      # Game continues
      true ->
        :in_progress
    end
  end

  defp has_no_legal_moves?(board, color) do
    # Check if there are any legal moves for the given color
    !Enum.any?(board.squares, fn
      {{from_file, from_rank}, {^color, _}} ->
        # Try all possible destinations
        Enum.any?(
          for to_file <- 0..7, to_rank <- 0..7 do
            to_pos = {to_file, to_rank}
            # Skip if the position is the same
            if to_pos != {from_file, from_rank} do
              case MoveValidator.validate_move(board, {from_file, from_rank}, to_pos, color) do
                {:ok, _} -> true
                _ -> false
              end
            else
              false
            end
          end
        )

      _ ->
        false
    end)
  end

  defp is_in_check?(board, king_pos, color) do
    MoveValidator.is_square_attacked?(board, king_pos, opposite_color(color))
  end

  defp find_king(board, color) do
    Enum.find_value(board.squares, fn
      {{file, rank}, {^color, :king}} -> {file, rank}
      _ -> nil
    end)
  end

  defp is_draw_by_insufficient_material?(board) do
    # Count pieces
    {white_pieces, black_pieces} =
      Enum.reduce(board.squares, {%{}, %{}}, fn
        {_, {color, piece_type}}, {white_count, black_count} ->
          if color == :white do
            {Map.update(white_count, piece_type, 1, &(&1 + 1)), black_count}
          else
            {white_count, Map.update(black_count, piece_type, 1, &(&1 + 1))}
          end
      end)

    # King vs King
    # King + Knight vs King
    # King + Bishop vs King
    (map_size(white_pieces) == 1 && map_size(black_pieces) == 1) ||
      (map_size(white_pieces) == 2 && Map.has_key?(white_pieces, :knight) &&
         map_size(black_pieces) == 1) ||
      (map_size(black_pieces) == 2 && Map.has_key?(black_pieces, :knight) &&
         map_size(white_pieces) == 1) ||
      (map_size(white_pieces) == 2 && Map.has_key?(white_pieces, :bishop) &&
         map_size(black_pieces) == 1) ||
      (map_size(black_pieces) == 2 && Map.has_key?(black_pieces, :bishop) &&
         map_size(white_pieces) == 1)
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
