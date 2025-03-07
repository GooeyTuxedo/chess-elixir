defmodule ChessApp.Games.Validators.RookMoveValidator do
  @moduledoc """
  Validates moves specific to rooks, which move horizontally or vertically.
  """

  @doc """
  Validates rook moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate({integer, integer}, {integer, integer}, any()) ::
    {:ok, atom()} | {:error, atom()}
  def validate({from_file, from_rank}, {to_file, to_rank}, target_piece) do
    if (to_file == from_file && to_rank != from_rank) ||
       (to_rank == from_rank && to_file != from_file) do
      if target_piece, do: {:ok, :capture}, else: {:ok, :normal}
    else
      {:error, :invalid_rook_move}
    end
  end
end
