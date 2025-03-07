defmodule ChessApp.Games.Validators.KingMoveValidator do
  @moduledoc """
  Validates moves specific to kings, including regular moves and castling.
  """

  alias ChessApp.Games.{Board, MoveValidator}

  @doc """
  Validates king moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate(Board.t(), {integer, integer}, {integer, integer}, Board.color()) ::
          {:ok, atom()} | {:error, atom()}
  def validate(board, from_pos = {from_file, from_rank}, to_pos = {to_file, to_rank}, color) do
    target_piece = Board.piece_at(board, to_pos)

    file_diff = abs(to_file - from_file)
    rank_diff = abs(to_rank - from_rank)

    cond do
      # Normal move (1 square in any direction)
      file_diff <= 1 && rank_diff <= 1 && (file_diff > 0 || rank_diff > 0) ->
        if target_piece, do: {:ok, :capture}, else: {:ok, :normal}

      # Kingside castling
      from_pos == {4, if(color == :white, do: 0, else: 7)} &&
        to_pos == {6, if(color == :white, do: 0, else: 7)} &&
          can_castle?(board, color, :kingside) ->
        {:ok, :castle_kingside}

      # Queenside castling
      from_pos == {4, if(color == :white, do: 0, else: 7)} &&
        to_pos == {2, if(color == :white, do: 0, else: 7)} &&
          can_castle?(board, color, :queenside) ->
        {:ok, :castle_queenside}

      true ->
        {:error, :invalid_king_move}
    end
  end

  # Private functions

  defp can_castle?(board, color, side) do
    # Check castling rights
    castling_rights = board.castling_rights[color][side]

    # King's rank
    rank = if color == :white, do: 0, else: 7

    # Check if the path is clear and not under attack
    case side do
      :kingside ->
        castling_rights &&
          Board.piece_at(board, {5, rank}) == nil &&
          Board.piece_at(board, {6, rank}) == nil &&
          !MoveValidator.is_square_attacked?(board, {4, rank}, opposite_color(color)) &&
          !MoveValidator.is_square_attacked?(board, {5, rank}, opposite_color(color)) &&
          !MoveValidator.is_square_attacked?(board, {6, rank}, opposite_color(color))

      :queenside ->
        castling_rights &&
          Board.piece_at(board, {1, rank}) == nil &&
          Board.piece_at(board, {2, rank}) == nil &&
          Board.piece_at(board, {3, rank}) == nil &&
          !MoveValidator.is_square_attacked?(board, {4, rank}, opposite_color(color)) &&
          !MoveValidator.is_square_attacked?(board, {3, rank}, opposite_color(color)) &&
          !MoveValidator.is_square_attacked?(board, {2, rank}, opposite_color(color))
    end
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
