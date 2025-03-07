defmodule ChessApp.Games.CaptureOwnPiecesTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.{Board, MoveValidator}

  describe "validate_move/4 with own pieces capture attempts" do
    test "prevents queen from capturing own pawn" do
      # Create a board with white queen and white pawn positioned for potential capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :queen},
          {5, 5} => {:white, :pawn}
        },
        turn: :white
      }

      # Queen attempts to capture own pawn (diagonal move)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 5}, :white)
    end

    test "prevents bishop from capturing own piece" do
      # Create a board with white bishop and white knight positioned for potential capture
      board = %Board{
        squares: %{
          {2, 2} => {:white, :bishop},
          {4, 4} => {:white, :knight}
        },
        turn: :white
      }

      # Bishop attempts to capture own knight (diagonal move)
      assert {:error, _} = MoveValidator.validate_move(board, {2, 2}, {4, 4}, :white)
    end

    test "prevents rook from capturing own piece" do
      # Create a board with white rook and white pawn positioned for potential capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :rook},
          {3, 6} => {:white, :pawn}
        },
        turn: :white
      }

      # Rook attempts to capture own pawn (vertical move)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {3, 6}, :white)
    end

    test "prevents knight from capturing own piece" do
      # Create a board with white knight and white pawn positioned for potential capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :knight},
          {5, 4} => {:white, :pawn}
        },
        turn: :white
      }

      # Knight attempts to capture own pawn (L-shaped move)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 4}, :white)
    end

    test "prevents king from capturing own piece" do
      # Create a board with white king and white pawn positioned for potential capture
      board = %Board{
        squares: %{
          {4, 4} => {:white, :king},
          {5, 5} => {:white, :pawn}
        },
        turn: :white
      }

      # King attempts to capture own pawn (diagonal move)
      assert {:error, _} = MoveValidator.validate_move(board, {4, 4}, {5, 5}, :white)
    end

    test "prevents pawn from capturing own piece" do
      # Create a board with white pawn and white bishop positioned for potential capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :pawn},
          {4, 4} => {:white, :bishop}
        },
        turn: :white
      }

      # Pawn attempts to capture own bishop (diagonal move)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {4, 4}, :white)
    end

    test "allows capturing opponent's pieces" do
      # Create a board with white bishop and black pawn positioned for potential capture
      board = %Board{
        squares: %{
          {2, 2} => {:white, :bishop},
          {4, 4} => {:black, :pawn}
        },
        turn: :white
      }

      # Bishop captures black pawn (diagonal move)
      assert {:ok, :capture} = MoveValidator.validate_move(board, {2, 2}, {4, 4}, :white)
    end

    test "prevents capture attempts of multiple own pieces" do
      # Create a board with multiple white pieces
      board = %Board{
        squares: %{
          {3, 3} => {:white, :queen},
          {3, 5} => {:white, :rook},
          {5, 3} => {:white, :bishop},
          {5, 5} => {:white, :knight}
        },
        turn: :white
      }

      # Queen attempts to capture own pieces in different directions
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {3, 5}, :white) # vertical
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 3}, :white) # horizontal
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 5}, :white) # diagonal
    end
  end
end
