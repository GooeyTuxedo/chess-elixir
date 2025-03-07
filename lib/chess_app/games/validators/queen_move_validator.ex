defmodule ChessApp.Games.Validators.QueenMoveValidator do
  @moduledoc """
  Validates moves specific to queens, which can move like a rook or bishop.
  """

  alias ChessApp.Games.Validators.{BishopMoveValidator, RookMoveValidator}

  def validate(_from_pos, nil, _target_piece) do
    {:error, :invalid_queen_move}
  end

  @doc """
  Validates queen moves according to chess rules.
  Returns {:ok, move_type} or {:error, reason}.
  """
  @spec validate({integer, integer}, {integer, integer}, any()) ::
          {:ok, atom()} | {:error, atom()}
  def validate(from, to, target_piece) do
    # Queen moves are valid if they would be valid for either a bishop or a rook
    case BishopMoveValidator.validate(from, to, target_piece) do
      {:ok, move_type} ->
        {:ok, move_type}

      {:error, _} ->
        case RookMoveValidator.validate(from, to, target_piece) do
          {:ok, move_type} -> {:ok, move_type}
          {:error, _} -> {:error, :invalid_queen_move}
        end
    end
  end
end
