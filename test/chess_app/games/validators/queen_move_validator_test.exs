defmodule ChessApp.Games.Validators.QueenMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Validators.QueenMoveValidator

  describe "validate/3" do
    test "validates horizontal moves" do
      # Test horizontal moves in both directions
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {7, 4}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {0, 4}, nil)

      # Test different horizontal distances
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {5, 4}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {3, 4}, nil)
    end

    test "validates vertical moves" do
      # Test vertical moves in both directions
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {4, 7}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {4, 0}, nil)

      # Test different vertical distances
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {4, 5}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {4, 3}, nil)
    end

    test "validates diagonal moves" do
      # Test all four diagonal directions
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {7, 7}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {1, 7}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {1, 1}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {7, 1}, nil)

      # Test different diagonal distances
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {5, 5}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {6, 6}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {3, 5}, nil)
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {2, 6}, nil)
    end

    test "validates captures" do
      # Queen capturing a piece (horizontal)
      assert {:ok, :capture} = QueenMoveValidator.validate({4, 4}, {7, 4}, {:black, :pawn})

      # Queen capturing a piece (vertical)
      assert {:ok, :capture} = QueenMoveValidator.validate({4, 4}, {4, 7}, {:black, :pawn})

      # Queen capturing a piece (diagonal)
      assert {:ok, :capture} = QueenMoveValidator.validate({4, 4}, {7, 7}, {:black, :pawn})

      # Queen moving to an empty square
      assert {:ok, :normal} = QueenMoveValidator.validate({4, 4}, {0, 4}, nil)
    end

    test "blocks invalid moves" do
      # Knight-like moves
      assert {:error, :invalid_queen_move} = QueenMoveValidator.validate({4, 4}, {6, 5}, nil)
      assert {:error, :invalid_queen_move} = QueenMoveValidator.validate({4, 4}, {2, 3}, nil)

      # Other irregular moves
      assert {:error, :invalid_queen_move} = QueenMoveValidator.validate({4, 4}, {6, 7}, nil)
      assert {:error, :invalid_queen_move} = QueenMoveValidator.validate({4, 4}, {1, 3}, nil)

      # No movement
      assert {:error, :invalid_queen_move} = QueenMoveValidator.validate({4, 4}, {4, 4}, nil)
    end
  end
end
