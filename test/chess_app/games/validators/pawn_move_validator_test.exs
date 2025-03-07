defmodule ChessApp.Games.Validators.PawnMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Board
  alias ChessApp.Games.Validators.PawnMoveValidator

  describe "validate/4" do
    test "validates forward move (1 square)" do
      board = %Board{squares: %{}}

      # White pawn moving forward one square
      assert {:ok, :normal} = PawnMoveValidator.validate(board, {3, 1}, {3, 2}, :white)

      # Black pawn moving forward one square
      assert {:ok, :normal} = PawnMoveValidator.validate(board, {3, 6}, {3, 5}, :black)
    end

    test "validates double push from starting position" do
      board = %Board{squares: %{}}

      # White pawn double push from starting rank
      assert {:ok, :double_push} = PawnMoveValidator.validate(board, {3, 1}, {3, 3}, :white)

      # Black pawn double push from starting rank
      assert {:ok, :double_push} = PawnMoveValidator.validate(board, {3, 6}, {3, 4}, :black)

      # Pawn not on starting rank can't double push
      board = %Board{squares: %{{3, 2} => {:white, :pawn}}}

      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 2}, {3, 4}, :white)
    end

    test "validates diagonal capture" do
      # Set up a board with pieces to capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :pawn},
          {4, 4} => {:black, :pawn},
          {2, 4} => {:black, :pawn}
        }
      }

      # White pawn capturing diagonally
      assert {:ok, :capture} = PawnMoveValidator.validate(board, {3, 3}, {4, 4}, :white)
      assert {:ok, :capture} = PawnMoveValidator.validate(board, {3, 3}, {2, 4}, :white)

      # Can't capture diagonally if no piece is present
      board = %Board{squares: %{{3, 3} => {:white, :pawn}}}

      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 3}, {4, 4}, :white)
    end

    test "validates en passant capture" do
      # Set up a board with en passant possibility
      board = %Board{
        squares: %{
          {3, 4} => {:white, :pawn},
          {4, 4} => {:black, :pawn}
        },
        en_passant_target: {4, 3}
      }

      # En passant capture
      assert {:ok, :en_passant} = PawnMoveValidator.validate(board, {3, 4}, {4, 3}, :white)

      # Can't en passant if the target isn't set correctly
      board = %Board{
        squares: %{
          {3, 4} => {:white, :pawn},
          {4, 4} => {:black, :pawn}
        },
        en_passant_target: nil
      }

      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 4}, {4, 3}, :white)
    end

    test "validates promotion" do
      # Set up a board with a pawn about to promote
      board = %Board{
        squares: %{
          {3, 6} => {:white, :pawn},
          {4, 6} => {:white, :pawn},
          {5, 7} => {:black, :rook}
        }
      }

      # Promotion by moving forward
      assert {:ok, :promotion} = PawnMoveValidator.validate(board, {3, 6}, {3, 7}, :white)

      # Promotion by capturing
      assert {:ok, :promotion} = PawnMoveValidator.validate(board, {4, 6}, {5, 7}, :white)
    end

    test "blocks invalid moves" do
      board = %Board{squares: %{}}

      # Can't move sideways
      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 3}, {4, 3}, :white)

      # Can't move backwards
      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 3}, {3, 2}, :white)

      # Can't move diagonally without capturing
      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 3}, {4, 4}, :white)

      # Can't move more than two squares
      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 1}, {3, 4}, :white)

      # Can't do double push if there's a piece in the way
      board = %Board{squares: %{{3, 2} => {:white, :pawn}}}

      assert {:error, :invalid_pawn_move} =
               PawnMoveValidator.validate(board, {3, 1}, {3, 3}, :white)
    end
  end
end
