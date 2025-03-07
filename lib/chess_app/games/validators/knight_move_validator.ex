defmodule ChessApp.Games.Validators.KnightMoveValidator do
  @moduledoc """
  Validates moves specific to knights, which move in an L-shape.
  """

  @doc """
  Validates knight moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate({integer, integer}, {integer, integer}, any()) ::
          {:ok, atom()} | {:error, atom()}
  def validate({from_file, from_rank}, {to_file, to_rank}, target_piece) do
    file_diff = abs(to_file - from_file)
    rank_diff = abs(to_rank - from_rank)

    if (file_diff == 1 && rank_diff == 2) || (file_diff == 2 && rank_diff == 1) do
      if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
    else
      {:error, :invalid_knight_move}
    end
  end
end
