defmodule ChessApp.Games.MoveValidator do
  @moduledoc """
  Validates chess moves according to standard chess rules.
  This module has been refactored to separate concerns and improve readability.
  """

  alias ChessApp.Games.Board
  alias ChessApp.Games.Validators.{
    PawnMoveValidator,
    KnightMoveValidator,
    BishopMoveValidator,
    RookMoveValidator,
    QueenMoveValidator,
    KingMoveValidator
  }

  @type position :: {0..7, 0..7}
  @type move_type ::
          :normal
          | :capture
          | :double_push
          | :en_passant
          | :castle_kingside
          | :castle_queenside
          | :promotion

  @doc """
  Validates if a move is legal for the current board state.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate_move(Board.t(), position(), position(), Board.color()) ::
          {:ok, move_type()} | {:error, atom()}
  def validate_move(board, from, to, player_color) do
    with {:ok, piece} <- get_piece(board, from),
          true <- is_players_piece?(piece, player_color),
          true <- is_players_turn?(board, piece) do

      # First, check if this move would result in check to own king
      if would_result_in_check?(board, from, to) do
        {:error, :would_result_in_check}
      else
        # Then check if trying to capture own piece
        if is_own_piece_at_target?(board, to, player_color) do
          {:error, :cannot_capture_own_piece}
        else
          # Finally validate the move according to piece rules
          case get_move_type(board, from, to, piece) do
            {:ok, move_type} ->
              if is_path_clear?(board, from, to, piece, move_type) do
                {:ok, move_type}
              else
                {:error, :path_not_clear}
              end
            error -> error
          end
        end
      end
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :illegal_move}
    end
  end

  @doc """
  Returns all valid moves for a piece at the given position.
  """
  @spec valid_moves(Board.t(), position()) :: [position()]
  def valid_moves(board, position) do
    case get_piece(board, position) do
      {:ok, piece} ->
        {color, _} = piece

        # Check all possible destination squares
        for file <- 0..7, rank <- 0..7, reduce: [] do
          acc ->
            to = {file, rank}
            # Skip the current position
            if to == position do
              acc
            else
              # Try each position as a potential destination
              case validate_move(board, position, to, color) do
                {:ok, _} -> [to | acc]
                _ -> acc
              end
            end
        end

      _ -> []
    end
  end

  @doc """
  Checks if a square is under attack by the given color.
  """
  @spec is_square_attacked?(Board.t(), position(), Board.color()) :: boolean()
  def is_square_attacked?(_board, nil, _attacking_color), do: false
  def is_square_attacked?(_board, _position, nil), do: false

  def is_square_attacked?(board, position, attacking_color) do
    # Check if any piece of the attacking color can capture the position
    Enum.any?(board.squares, fn
      {{_from_file, _from_rank}, {^attacking_color, :pawn}} = {from_pos, _piece} ->
        # Use special pawn attack check
        is_pawn_attacking?(from_pos, position, attacking_color)

      {{from_file, from_rank}, {^attacking_color, :king}} = {_from_pos, _piece} ->
        # For kings, just check if they're adjacent
        file_diff = abs(from_file - elem(position, 0))
        rank_diff = abs(from_rank - elem(position, 1))
        file_diff <= 1 && rank_diff <= 1

      {{_from_file, _from_rank}, {^attacking_color, _piece_type}} = {from_pos, piece} ->
        # For other pieces, check if they can move to the position
        case get_move_type(board, from_pos, position, piece) do
          {:ok, _} ->
            # Additionally verify the path is clear (doesn't apply to knights)
            is_path_clear?(board, from_pos, position, piece, :normal)
          _ -> false
        end

      _ -> false
    end)
  end

  # Private functions

  defp get_piece(board, position) do
    case Board.piece_at(board, position) do
      nil -> {:error, :no_piece}
      piece -> {:ok, piece}
    end
  end

  defp is_players_piece?({color, _}, player_color) do
    color == player_color
  end

  defp is_players_turn?(board, {color, _}) do
    board.turn == color
  end

  # Check if the target square contains a piece of the player's color
  defp is_own_piece_at_target?(board, to, player_color) do
    case Board.piece_at(board, to) do
      {piece_color, _} -> piece_color == player_color
      nil -> false
    end
  end

  defp get_move_type(board, from, to, {color, :pawn}) do
    PawnMoveValidator.validate(board, from, to, color)
  end

  defp get_move_type(board, from, to, {_color, :knight}) do
    KnightMoveValidator.validate(from, to, board.squares[to])
  end

  defp get_move_type(board, from, to, {_color, :bishop}) do
    BishopMoveValidator.validate(from, to, board.squares[to])
  end

  defp get_move_type(board, from, to, {_color, :rook}) do
    RookMoveValidator.validate(from, to, board.squares[to])
  end

  defp get_move_type(board, from, to, {_color, :queen}) do
    QueenMoveValidator.validate(from, to, board.squares[to])
  end

  defp get_move_type(board, from, to, {color, :king}) do
    KingMoveValidator.validate(board, from, to, color)
  end

  defp get_move_type(_, _, _, _) do
    {:error, :unknown_piece_type}
  end

  defp is_path_clear?(_board, _from, nil, _piece, _move_type), do: false
  defp is_path_clear?(_board, nil, _to, _piece, _move_type), do: false

  defp is_path_clear?(board, from, to, {_, piece_type}, _move_type) do
    {from_file, from_rank} = from
    {to_file, to_rank} = to

    # Knights can jump over pieces
    if piece_type == :knight do
      true
    else
      # For diagonal, horizontal, and vertical moves, check if the path is clear
      file_step = get_step(from_file, to_file)
      rank_step = get_step(from_rank, to_rank)

      # Start one step away from the source position
      check_file = from_file + file_step
      check_rank = from_rank + rank_step

      # Check each position until we reach the destination (exclusive)
      check_path_clear(board, check_file, check_rank, to_file, to_rank, file_step, rank_step)
    end
  end

  defp check_path_clear(board, file, rank, to_file, to_rank, file_step, rank_step) do
    if file == to_file and rank == to_rank do
      true
    else
      if Board.piece_at(board, {file, rank}) == nil do
        check_path_clear(board, file + file_step, rank + rank_step, to_file, to_rank, file_step, rank_step)
      else
        false
      end
    end
  end

  defp get_step(from, to) do
    cond do
      from < to -> 1
      from > to -> -1
      true -> 0
    end
  end

  defp is_pawn_attacking?({_from_file, _from_rank}, nil, _attacking_color), do: false

  defp is_pawn_attacking?({from_file, from_rank}, {to_file, to_rank}, attacking_color) do
    file_diff = abs(to_file - from_file)
    direction = if attacking_color == :white, do: 1, else: -1
    rank_diff = to_rank - from_rank

    # Pawns attack diagonally in the forward direction
    file_diff == 1 && rank_diff == direction
  end

  defp would_result_in_check?(board, from, to) do
    # Simulate the move
    {piece, new_board} = simulate_move(board, from, to)

    # Find the king's position after the move
    king_color = elem(piece, 0)
    king_pos = find_king(new_board, king_color)

    # Check if the king would be attacked after the move
    is_square_attacked?(new_board, king_pos, opposite_color(king_color))
  end

  defp simulate_move(board, from, to) do
    piece = Board.piece_at(board, from)
    new_squares = board.squares
                  |> Map.delete(from)
                  |> Map.put(to, piece)

    new_board = %{board | squares: new_squares}
    {piece, new_board}
  end

  defp find_king(board, color) do
    Enum.find_value(board.squares, fn
      {{file, rank}, {^color, :king}} -> {file, rank}
      _ -> nil
    end)
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
