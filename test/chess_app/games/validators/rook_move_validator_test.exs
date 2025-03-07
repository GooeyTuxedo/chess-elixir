defmodule ChessApp.Games.Validators.RookMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Validators.RookMoveValidator

  describe "validate/3" do
    test "validates horizontal moves" do
      # Test horizontal moves in both directions
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {7, 4}, nil)
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {0, 4}, nil)

      # Test different horizontal distances
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {5, 4}, nil)
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {3, 4}, nil)
    end

    test "validates vertical moves" do
      # Test vertical moves in both directions
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {4, 7}, nil)
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {4, 0}, nil)

      # Test different vertical distances
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {4, 5}, nil)
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {4, 3}, nil)
    end

    test "validates captures" do
      # Rook capturing a piece
      assert {:ok, :capture} = RookMoveValidator.validate({4, 4}, {4, 7}, {:black, :pawn})

      # Rook moving to an empty square
      assert {:ok, :normal} = RookMoveValidator.validate({4, 4}, {0, 4}, nil)
    end

    test "blocks invalid moves" do
      # Diagonal moves
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {6, 6}, nil)
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {2, 2}, nil)
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {6, 2}, nil)
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {2, 6}, nil)

      # Knight-like moves
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {6, 5}, nil)
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {2, 3}, nil)

      # Other irregular moves
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {6, 7}, nil)
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {1, 3}, nil)

      # No movement
      assert {:error, :invalid_rook_move} = RookMoveValidator.validate({4, 4}, {4, 4}, nil)
    end
  end
end
