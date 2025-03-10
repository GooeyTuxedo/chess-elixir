defmodule ChessApp.Games.ChessNotation do
  @moduledoc """
  Converts chess moves to standard algebraic notation.
  """

  @doc """
  Converts a move to algebraic notation.

  Examples:
    - e4 (pawn move)
    - Nf3 (knight to f3)
    - Bxd5 (bishop captures on d5)
    - O-O (kingside castling)
    - e8=Q (pawn promotion to queen)
    - Qh4# (queen delivers checkmate)
    - Rd1+ (rook gives check)
  """
  def to_algebraic_notation(move, board, is_check, is_checkmate) do
    # Extract move information
    {from_file, _from_rank} = move.from
    {to_file, to_rank} = move.to
    {_piece_color, piece_type} = move.piece
    move_type = move.move_type

    # Convert coordinates to algebraic notation
    to_square = file_to_letter(to_file) <> Integer.to_string(to_rank + 1)

    notation = case {piece_type, move_type} do
      # Special cases first
      {_, :castle_kingside} -> "O-O"
      {_, :castle_queenside} -> "O-O-O"

      # Pawn promotion
      {:pawn, :promotion} ->
        from_file_letter = file_to_letter(from_file)
        promotion_piece_letter = piece_type_to_letter(move.promotion_piece)

        # Include x if it was a capture
        capture_notation = if board.squares[move.to] != nil, do: "x", else: ""
        "#{from_file_letter}#{capture_notation}#{to_square}=#{promotion_piece_letter}"

      # Pawn special cases
      {:pawn, :capture} ->
        "#{file_to_letter(from_file)}x#{to_square}"
      {:pawn, :en_passant} ->
        "#{file_to_letter(from_file)}x#{to_square} e.p."
      {:pawn, _} ->
        "#{to_square}"

      # Other pieces
      {_, _} ->
        piece_letter = piece_type_to_letter(piece_type)
        # Add disambiguation if needed
        disambiguator = get_disambiguator(board, move)
        # Include x for captures
        capture_notation = if move_type == :capture, do: "x", else: ""

        "#{piece_letter}#{disambiguator}#{capture_notation}#{to_square}"
    end

    # Add check or checkmate symbols
    notation = cond do
      is_checkmate -> notation <> "#"
      is_check -> notation <> "+"
      true -> notation
    end

    notation
  end

  # Get disambiguator for moves when two pieces of the same type can move to the same square
  defp get_disambiguator(board, move) do
    {piece_color, piece_type} = move.piece
    {to_file, to_rank} = move.to
    {from_file, from_rank} = move.from

    # Find other pieces of the same type that could move to the same square
    # This is a simplified version that doesn't account for pins and other restrictions
    other_same_pieces = Enum.filter(board.squares, fn
      {pos, {^piece_color, ^piece_type}} when pos != move.from -> true
      _ -> false
    end)

    same_pieces_that_can_move_to_target = Enum.filter(other_same_pieces, fn {{pos_file, pos_rank}, _piece} ->
      # Very simplified check - in a real chess engine, you'd use the actual move validator
      case piece_type do
        :knight ->
          (abs(pos_file - to_file) == 1 && abs(pos_rank - to_rank) == 2) ||
          (abs(pos_file - to_file) == 2 && abs(pos_rank - to_rank) == 1)
        :bishop ->
          abs(pos_file - to_file) == abs(pos_rank - to_rank)
        :rook ->
          pos_file == to_file || pos_rank == to_rank
        :queen ->
          pos_file == to_file || pos_rank == to_rank ||
          abs(pos_file - to_file) == abs(pos_rank - to_rank)
        _ -> false
      end
    end)

    case same_pieces_that_can_move_to_target do
      [] -> ""
      _ ->
        # Disambiguate by file if possible
        if Enum.any?(same_pieces_that_can_move_to_target, fn {{pos_file, _}, _} ->
          pos_file == from_file
        end) do
          "#{from_rank + 1}"
        else
          "#{file_to_letter(from_file)}"
        end
    end
  end

  defp file_to_letter(file) do
    case file do
      0 -> "a"
      1 -> "b"
      2 -> "c"
      3 -> "d"
      4 -> "e"
      5 -> "f"
      6 -> "g"
      7 -> "h"
      _ -> "?"
    end
  end

  defp piece_type_to_letter(piece_type) do
    case piece_type do
      :king -> "K"
      :queen -> "Q"
      :rook -> "R"
      :bishop -> "B"
      :knight -> "N"
      :pawn -> ""
      _ -> "?"
    end
  end
end
