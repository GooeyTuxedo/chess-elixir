defmodule ChessApp.Games.MoveValidator do
  @moduledoc """
  Validates chess moves according to standard chess rules.
  """

  alias ChessApp.Games.Board

  @doc """
  Validates if a move is legal for the current board state.
  Returns {:ok, move_type} or {:error, reason}.
  """
  def validate_move(board, from, to, player_color) do
    with {:ok, piece} <- get_piece(board, from),
         true <- is_players_piece?(piece, player_color),
         true <- is_players_turn?(board, piece),
         {:ok, move_type} <- get_move_type(board, from, to, piece),
         true <- is_path_clear?(board, from, to, piece, move_type),
         false <- would_result_in_check?(board, from, to) do
      {:ok, move_type}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :illegal_move}
      true -> {:error, :would_result_in_check}
    end
  end

  @doc """
  Returns all valid moves for a piece at the given position.
  """
  def valid_moves(board, position) do
    case get_piece(board, position) do
      {:ok, piece} ->
        # Check all possible destination squares
        for file <- 0..7, rank <- 0..7 do
          to = {file, rank}
          case validate_move(board, position, to, elem(piece, 0)) do
            {:ok, _} -> to
            _ -> nil
          end
        end
        |> Enum.reject(&is_nil/1)

      _ -> []
    end
  end

  @doc """
  Checks if a square is under attack by the given color.
  """
  def is_square_attacked?(board, position, attacking_color) do
    # Check if any piece of the attacking color can capture the position
    Enum.any?(board.squares, fn
      {{from_file, from_rank}, {^attacking_color, _}} = {from_pos, piece} ->
        # Skip checking for king to avoid infinite recursion
        if elem(piece, 1) == :king do
          # For kings, just check if they're adjacent
          file_diff = abs(from_file - elem(position, 0))
          rank_diff = abs(from_rank - elem(position, 1))
          file_diff <= 1 && rank_diff <= 1
        else
          # For other pieces, check if they can move to the position
          case get_move_type(board, from_pos, position, piece) do
            {:ok, _} ->
              # Additionally verify the path is clear (doesn't apply to knights)
              is_path_clear?(board, from_pos, position, piece, :normal)
            _ -> false
          end
        end
      _ -> false
    end)
  end

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

  defp get_move_type(board, from, to, {color, piece_type}) do
    target_piece = Board.piece_at(board, to)
    {from_file, from_rank} = from
    {to_file, to_rank} = to

    cond do
      # Can't move to the same square
      from == to ->
        {:error, :same_position}

      # Can't capture own piece
      target_piece && elem(target_piece, 0) == color ->
        {:error, :cannot_capture_own_piece}

      # Pawn moves
      piece_type == :pawn ->
        validate_pawn_move(board, from, to, color, target_piece)

      # Knight moves
      piece_type == :knight ->
        file_diff = abs(to_file - from_file)
        rank_diff = abs(to_rank - from_rank)
        if (file_diff == 1 && rank_diff == 2) || (file_diff == 2 && rank_diff == 1) do
          if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
        else
          {:error, :invalid_knight_move}
        end

      # Bishop moves
      piece_type == :bishop ->
        if abs(to_file - from_file) == abs(to_rank - from_rank) do
          if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
        else
          {:error, :invalid_bishop_move}
        end

      # Rook moves
      piece_type == :rook ->
        if (to_file == from_file) || (to_rank == from_rank) do
          if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
        else
          {:error, :invalid_rook_move}
        end

      # Queen moves (bishop + rook)
      piece_type == :queen ->
        diag_move = abs(to_file - from_file) == abs(to_rank - from_rank)
        straight_move = (to_file == from_file) || (to_rank == from_rank)

        if diag_move || straight_move do
          if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
        else
          {:error, :invalid_queen_move}
        end

      # King moves
      piece_type == :king ->
        file_diff = abs(to_file - from_file)
        rank_diff = abs(to_rank - from_rank)

        cond do
          # Normal move (1 square in any direction)
          file_diff <= 1 && rank_diff <= 1 ->
            if target_piece, do: {:ok, :capture}, else: {:ok, :normal}

          # Kingside castling
          from == {4, (if color == :white, do: 0, else: 7)} &&
          to == {6, (if color == :white, do: 0, else: 7)} &&
          can_castle?(board, color, :kingside) ->
            {:ok, :castle_kingside}

          # Queenside castling
          from == {4, (if color == :white, do: 0, else: 7)} &&
          to == {2, (if color == :white, do: 0, else: 7)} &&
          can_castle?(board, color, :queenside) ->
            {:ok, :castle_queenside}

          true ->
            {:error, :invalid_king_move}
        end

      true ->
        {:error, :unknown_piece_type}
    end
  end

  defp validate_pawn_move(board, {from_file, from_rank}, {to_file, to_rank}, color, target_piece) do
    direction = if color == :white, do: 1, else: -1
    start_rank = if color == :white, do: 1, else: 6
    promotion_rank = if color == :white, do: 7, else: 0
    file_diff = abs(to_file - from_file)
    rank_diff = to_rank - from_rank

    cond do
      # Forward move (1 square)
      file_diff == 0 && rank_diff == direction && target_piece == nil ->
        if to_rank == promotion_rank do
          {:ok, :promotion}
        else
          {:ok, :normal}
        end

      # Forward move (2 squares) from starting position
      file_diff == 0 && rank_diff == 2 * direction &&
      from_rank == start_rank && target_piece == nil &&
      Board.piece_at(board, {from_file, from_rank + direction}) == nil ->
        {:ok, :double_push}

      # Diagonal capture
      file_diff == 1 && rank_diff == direction && target_piece != nil ->
        if to_rank == promotion_rank do
          {:ok, :promotion}
        else
          {:ok, :capture}
        end

      # En passant capture
      file_diff == 1 && rank_diff == direction && target_piece == nil &&
      board.en_passant_target == {to_file, to_rank} ->
        {:ok, :en_passant}

      true ->
        {:error, :invalid_pawn_move}
    end
  end

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
      Enum.all?(
        Stream.unfold({check_file, check_rank}, fn
          {f, r} when f == to_file and r == to_rank -> nil
          {f, r} -> {{f, r}, {f + file_step, r + rank_step}}
        end),
        fn pos -> Board.piece_at(board, pos) == nil end
      )
    end
  end

  defp get_step(from, to) do
    cond do
      from < to -> 1
      from > to -> -1
      true -> 0
    end
  end

  defp can_castle?(board, color, side) do
    # Check castling rights
    castling_rights = board.castling_rights[color][side]

    # King's rank
    rank = if color == :white, do: 0, else: 7

    # Check if the path is clear
    case side do
      :kingside ->
        castling_rights &&
        Board.piece_at(board, {5, rank}) == nil &&
        Board.piece_at(board, {6, rank}) == nil &&
        !is_square_attacked?(board, {4, rank}, opposite_color(color)) &&
        !is_square_attacked?(board, {5, rank}, opposite_color(color)) &&
        !is_square_attacked?(board, {6, rank}, opposite_color(color))

      :queenside ->
        castling_rights &&
        Board.piece_at(board, {1, rank}) == nil &&
        Board.piece_at(board, {2, rank}) == nil &&
        Board.piece_at(board, {3, rank}) == nil &&
        !is_square_attacked?(board, {4, rank}, opposite_color(color)) &&
        !is_square_attacked?(board, {3, rank}, opposite_color(color)) &&
        !is_square_attacked?(board, {2, rank}, opposite_color(color))
    end
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white

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
end
