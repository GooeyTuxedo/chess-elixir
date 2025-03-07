defmodule ChessApp.Games.Validators.KnightMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Validators.KnightMoveValidator

  describe "validate/3" do
    test "validates L-shaped moves" do
      # All eight possible L-shaped moves from the center
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {2, 3}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {2, 5}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {3, 2}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {3, 6}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {5, 2}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {5, 6}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {6, 3}, nil)
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {6, 5}, nil)
    end

    test "validates captures" do
      # Knight capturing a piece
      assert {:ok, :capture} = KnightMoveValidator.validate({4, 4}, {2, 3}, {:black, :pawn})

      # Knight moving to an empty square
      assert {:ok, :normal} = KnightMoveValidator.validate({4, 4}, {2, 5}, nil)
    end

    test "blocks invalid moves" do
      # Straight moves (not L-shaped)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {4, 5}, nil)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {5, 4}, nil)

      # Diagonal moves (not L-shaped)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {5, 5}, nil)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {3, 3}, nil)

      # Too far away
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {7, 7}, nil)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {0, 0}, nil)

      # Weird coordinates that don't match any valid knight pattern
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {1, 1}, nil)
      assert {:error, :invalid_knight_move} = KnightMoveValidator.validate({4, 4}, {7, 4}, nil)
    end
  end
end
