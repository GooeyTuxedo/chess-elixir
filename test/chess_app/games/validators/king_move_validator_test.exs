defmodule ChessApp.Games.Validators.KingMoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Board
  alias ChessApp.Games.Validators.KingMoveValidator

  describe "validate/4" do
    test "validates one-step moves in all directions" do
      board = %Board{squares: %{}}

      # Test all eight adjacent squares
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {3, 3}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {3, 4}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {3, 5}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {4, 3}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {4, 5}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {5, 3}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {5, 4}, :white)
      assert {:ok, :normal} = KingMoveValidator.validate(board, {4, 4}, {5, 5}, :white)
    end

    test "validates captures" do
      # Create a board with a piece to capture
      board = %Board{
        squares: %{
          {4, 4} => {:white, :king},
          {5, 5} => {:black, :pawn}
        }
      }

      assert {:ok, :capture} = KingMoveValidator.validate(board, {4, 4}, {5, 5}, :white)
    end

    test "validates kingside castling" do
      # Create a board with castling possibility
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:ok, :castle_kingside} = KingMoveValidator.validate(board, {4, 0}, {6, 0}, :white)

      # Test black king castling
      board = %Board{
        squares: %{
          {4, 7} => {:black, :king},
          {7, 7} => {:black, :rook}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:ok, :castle_kingside} = KingMoveValidator.validate(board, {4, 7}, {6, 7}, :black)
    end

    test "validates queenside castling" do
      # Create a board with castling possibility
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {0, 0} => {:white, :rook}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:ok, :castle_queenside} = KingMoveValidator.validate(board, {4, 0}, {2, 0}, :white)

      # Test black king castling
      board = %Board{
        squares: %{
          {4, 7} => {:black, :king},
          {0, 7} => {:black, :rook}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:ok, :castle_queenside} = KingMoveValidator.validate(board, {4, 7}, {2, 7}, :black)
    end

    test "blocks castling when path is blocked" do
      # Create a board with pieces in the way of castling
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook},
          # Bishop blocking the path
          {5, 0} => {:white, :bishop}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 0}, {6, 0}, :white)
    end

    test "blocks castling when castling rights are lost" do
      # Create a board with no castling rights
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook}
        },
        castling_rights: %{
          white: %{kingside: false, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 0}, {6, 0}, :white)
    end

    test "blocks invalid moves" do
      board = %Board{squares: %{}}

      # Moving too far horizontally
      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 4}, {6, 4}, :white)

      # Moving too far vertically
      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 4}, {4, 6}, :white)

      # Moving too far diagonally
      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 4}, {6, 6}, :white)

      # Knight-like moves
      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 4}, {6, 5}, :white)

      # No movement
      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 4}, {4, 4}, :white)

      # Invalid castling (wrong destination)
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook}
        },
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      assert {:error, :invalid_king_move} =
               KingMoveValidator.validate(board, {4, 0}, {7, 0}, :white)
    end
  end
end
