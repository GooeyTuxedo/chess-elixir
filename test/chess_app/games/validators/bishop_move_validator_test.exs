defmodule ChessApp.Games.Validators.BishopMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Validators.BishopMoveValidator

  describe "validate/3" do
    test "validates diagonal moves" do
      # Test all four diagonal directions
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {7, 7}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {1, 7}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {1, 1}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {7, 1}, nil)

      # Test different diagonal distances
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {5, 5}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {6, 6}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {3, 5}, nil)
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {2, 6}, nil)
    end

    test "validates captures" do
      # Bishop capturing a piece
      assert {:ok, :capture} = BishopMoveValidator.validate({4, 4}, {6, 6}, {:black, :pawn})

      # Bishop moving to an empty square
      assert {:ok, :normal} = BishopMoveValidator.validate({4, 4}, {2, 6}, nil)
    end

    test "blocks invalid moves" do
      # Horizontal moves
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {7, 4}, nil)
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {0, 4}, nil)

      # Vertical moves
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {4, 7}, nil)
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {4, 0}, nil)

      # Knight-like moves (not diagonal)
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {6, 5}, nil)
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {2, 3}, nil)

      # Other non-diagonal patterns
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {6, 7}, nil)
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {1, 3}, nil)

      # No movement
      assert {:error, :invalid_bishop_move} = BishopMoveValidator.validate({4, 4}, {4, 4}, nil)
    end
  end
end
