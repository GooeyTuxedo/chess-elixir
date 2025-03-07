defmodule ChessApp.Games.Validators.BishopMoveValidator do
  @moduledoc """
  Validates moves specific to bishops, which move diagonally.
  """

  @doc """
  Validates bishop moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate({integer, integer}, {integer, integer}, any()) ::
          {:ok, atom()} | {:error, atom()}
  def validate({from_file, from_rank}, {to_file, to_rank}, target_piece) do
    file_diff = abs(to_file - from_file)
    rank_diff = abs(to_rank - from_rank)

    if file_diff == rank_diff && file_diff > 0 do
      if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
    else
      {:error, :invalid_bishop_move}
    end
  end
end
