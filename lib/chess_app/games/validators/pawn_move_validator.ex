defmodule ChessApp.Games.Validators.PawnMoveValidator do
  @moduledoc """
  Validates moves specific to pawns, including forward moves, captures,
  en passant, and promotions.
  """

  alias ChessApp.Games.Board

  @doc """
  Validates pawn moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate(Board.t(), {integer, integer}, {integer, integer}, Board.color()) ::
          {:ok, atom()} | {:error, atom()}
  def validate(board, {from_file, from_rank}, {to_file, to_rank}, color) do
    target_piece = Board.piece_at(board, {to_file, to_rank})

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
end
