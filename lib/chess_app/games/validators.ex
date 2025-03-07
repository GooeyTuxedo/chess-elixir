defmodule ChessApp.Games.Validators do
  @moduledoc """
  A facade module that provides access to all piece-specific validators.
  """

  defmacro __using__(_) do
    quote do
      alias ChessApp.Games.Validators.{
        PawnMoveValidator,
        KnightMoveValidator,
        BishopMoveValidator,
        RookMoveValidator,
        QueenMoveValidator,
        KingMoveValidator
      }
    end
  end
end
