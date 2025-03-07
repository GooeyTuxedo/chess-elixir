# lib/chess_app/games/game_server.ex
defmodule ChessApp.Games.GameServer do
  use GenServer
  alias ChessApp.Games.Board

  alias ChessApp.Games.MoveValidator

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  def create_game do
    game_id = generate_game_id()

    DynamicSupervisor.start_child(
      ChessApp.GameSupervisor,
      {__MODULE__, [game_id: game_id]}
    )

    {:ok, game_id}
  end

  def join_game(game_id, player_session_id, player_nickname) do
    GenServer.call(via_tuple(game_id), {:join_game, player_session_id, player_nickname})
  end

  def make_move(game_id, player_session_id, from, to) do
    GenServer.call(via_tuple(game_id), {:make_move, player_session_id, from, to})
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)

    {:ok, %{
      game_id: game_id,
      board: Board.new(),
      players: %{
        white: nil, # Will store {session_id, nickname} tuples
        black: nil
      },
      status: :waiting_for_players,
      move_history: []
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
      # If game is full, return error
      if state.players.white && state.players.black do
        {:reply, {:error, :game_full}, state}
      else
        # Assign player to first available color
        color = if is_nil(state.players.white), do: :white, else: :black

        # Update players map
        players = Map.put(state.players, color, {player_session_id, player_nickname})

        # Check if game can now start
        status = if players.white && players.black, do: :in_progress, else: :waiting_for_players

        # Update state
        state = %{state | players: players, status: status}

        # Broadcast new player
        Phoenix.PubSub.broadcast(
          ChessApp.PubSub,
          "game:#{state.game_id}",
          {:player_joined, color, player_nickname}
        )

        {:reply, {:ok, color}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:make_move, player_session_id, from, to}, _from, state) do
    player_color = get_player_color(state, player_session_id)

    # Check if it's a valid player and it's their turn
    if player_color && player_color == state.board.turn do
      # Validate the move
      case MoveValidator.validate_move(state.board, from, to, player_color) do
        {:ok, move_type} ->
          # Execute the move
          {:ok, new_board} = Board.make_move(state.board, from, to, move_type)

          # Record the move
          move = %{
            from: from,
            to: to,
            piece: Board.piece_at(state.board, from),
            move_type: move_type,
            player_color: player_color,
            timestamp: DateTime.utc_now()
          }

          # Check for game end conditions
          game_status = check_game_status(new_board)

          # Update state
          new_state = %{state |
            board: new_board,
            status: game_status,
            move_history: [move | state.move_history]
          }

          # Broadcast the move
          Phoenix.PubSub.broadcast(
            ChessApp.PubSub,
            "game:#{state.game_id}",
            {:move_made, move, new_state}
          )

          {:reply, {:ok, move_type}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      reason = cond do
        !player_color -> :not_a_player
        player_color != state.board.turn -> :not_your_turn
        true -> :unknown_error
      end

      {:reply, {:error, reason}, state}
    end
  end


  # Helper functions

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

    cond do
      white_in_check && is_checkmate?(board, :white) ->
        :checkmate_white

      black_in_check && is_checkmate?(board, :black) ->
        :checkmate_black

      is_stalemate?(board) ->
        :stalemate

      is_draw_by_insufficient_material?(board) ->
        :draw_insufficient_material

      board.halfmove_clock >= 100 ->
        :draw_fifty_move_rule

      true ->
        if white_in_check do
          :check_white
        else if black_in_check do
          :check_black
        else
          :in_progress
        end
      end
    end
  end

  defp find_king(board, color) do
    Enum.find_value(board.squares, fn
      {{file, rank}, {^color, :king}} -> {file, rank}
      _ -> nil
    end)
  end

  defp is_in_check?(board, king_pos, color) do
    MoveValidator.is_square_attacked?(board, king_pos, opposite_color(color))
  end

  defp is_checkmate?(board, color) do
    # Check if there are any legal moves that would get out of check
    !Enum.any?(board.squares, fn
      {{from_file, from_rank}, {^color, _}} ->
        # Check all possible moves for this piece
        Enum.any?(for to_file <- 0..7, to_rank <- 0..7 do
          case MoveValidator.validate_move(board, {from_file, from_rank}, {to_file, to_rank}, color) do
            {:ok, _} -> true
            _ -> false
          end
        end)
      _ -> false
    end)
  end

  defp is_stalemate?(board) do
    color = board.turn
    king_pos = find_king(board, color)

    # Not in check
    !is_in_check?(board, king_pos, color) &&
    # But no legal moves
    !Enum.any?(board.squares, fn
      {{from_file, from_rank}, {^color, _}} ->
        # Check all possible moves for this piece
        Enum.any?(for to_file <- 0..7, to_rank <- 0..7 do
          case MoveValidator.validate_move(board, {from_file, from_rank}, {to_file, to_rank}, color) do
            {:ok, _} -> true
            _ -> false
          end
        end)
      _ -> false
    end)
  end

  defp is_draw_by_insufficient_material?(board) do
    # Count pieces
    {white_pieces, black_pieces} = Enum.reduce(board.squares, {%{}, %{}}, fn
      {_, {color, piece_type}}, {white_count, black_count} ->
        if color == :white do
          {Map.update(white_count, piece_type, 1, &(&1 + 1)), black_count}
        else
          {white_count, Map.update(black_count, piece_type, 1, &(&1 + 1))}
        end
    end)

    # King vs King
    (map_size(white_pieces) == 1 && map_size(black_pieces) == 1) ||
    # King + Knight vs King
    (map_size(white_pieces) == 2 && Map.has_key?(white_pieces, :knight) && map_size(black_pieces) == 1) ||
    (map_size(black_pieces) == 2 && Map.has_key?(black_pieces, :knight) && map_size(white_pieces) == 1) ||
    # King + Bishop vs King
    (map_size(white_pieces) == 2 && Map.has_key?(white_pieces, :bishop) && map_size(black_pieces) == 1) ||
    (map_size(black_pieces) == 2 && Map.has_key?(black_pieces, :bishop) && map_size(white_pieces) == 1)
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
