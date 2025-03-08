defmodule ChessApp.Games.MoveValidatorTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.{Board, MoveValidator}

  describe "validate_move/4" do
    test "validates basic pawn moves" do
      board = Board.new()

      # White pawn forward one square
      assert {:ok, :normal} = MoveValidator.validate_move(board, {0, 1}, {0, 2}, :white)

      # White pawn forward two squares from starting position
      assert {:ok, :double_push} = MoveValidator.validate_move(board, {1, 1}, {1, 3}, :white)

      # Attempt to move white pawn forward three squares (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {2, 1}, {2, 4}, :white)

      # Attempt to move white pawn diagonally without capture (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 1}, {4, 2}, :white)
    end

    test "validates pawn captures" do
      # Create a board with pawns in position to capture
      board = %Board{
        squares: %{
          {3, 3} => {:white, :pawn},
          {4, 4} => {:black, :pawn}
        },
        turn: :white
      }

      # White pawn captures black pawn
      assert {:ok, :capture} = MoveValidator.validate_move(board, {3, 3}, {4, 4}, :white)

      # White pawn attempts diagonal move without a piece to capture (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {2, 4}, :white)
    end

    test "validates knight moves" do
      board = Board.new()

      # Knight L-shaped move
      assert {:ok, :normal} = MoveValidator.validate_move(board, {1, 0}, {2, 2}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {1, 0}, {0, 2}, :white)

      # Invalid knight move (not L-shaped)
      assert {:error, _} = MoveValidator.validate_move(board, {1, 0}, {1, 2}, :white)
      assert {:error, _} = MoveValidator.validate_move(board, {1, 0}, {3, 3}, :white)
    end

    test "validates bishop moves" do
      # Create a board with a bishop in the open
      board = %Board{
        squares: %{
          {2, 2} => {:white, :bishop}
        },
        turn: :white
      }

      # Diagonal moves
      assert {:ok, :normal} = MoveValidator.validate_move(board, {2, 2}, {0, 0}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {2, 2}, {5, 5}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {2, 2}, {0, 4}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {2, 2}, {4, 0}, :white)

      # Non-diagonal move (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {2, 2}, {2, 5}, :white)
    end

    test "validates rook moves" do
      # Create a board with a rook in the open
      board = %Board{
        squares: %{
          {3, 3} => {:white, :rook}
        },
        turn: :white
      }

      # Horizontal and vertical moves
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {3, 7}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {3, 0}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {0, 3}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {7, 3}, :white)

      # Diagonal move (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 5}, :white)
    end

    test "validates queen moves" do
      # Create a board with a queen in the open
      board = %Board{
        squares: %{
          {3, 3} => {:white, :queen}
        },
        turn: :white
      }

      # Horizontal, vertical, and diagonal moves
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {3, 7}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {7, 3}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {0, 0}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {3, 3}, {5, 5}, :white)

      # Invalid move (neither straight nor diagonal)
      assert {:error, _} = MoveValidator.validate_move(board, {3, 3}, {5, 6}, :white)
    end

    test "validates king moves" do
      # Create a board with a king in the open
      board = %Board{
        squares: %{
          {4, 4} => {:white, :king}
        },
        turn: :white
      }

      # One square in any direction
      assert {:ok, :normal} = MoveValidator.validate_move(board, {4, 4}, {4, 5}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {4, 4}, {5, 5}, :white)
      assert {:ok, :normal} = MoveValidator.validate_move(board, {4, 4}, {3, 3}, :white)

      # More than one square (invalid)
      assert {:error, _} = MoveValidator.validate_move(board, {4, 4}, {4, 6}, :white)
      assert {:error, _} = MoveValidator.validate_move(board, {4, 4}, {6, 6}, :white)
    end

    test "validates castling" do
      # Create a board where castling is possible
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook},
          {0, 0} => {:white, :rook}
        },
        turn: :white,
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      # Kingside castling
      assert {:ok, :castle_kingside} = MoveValidator.validate_move(board, {4, 0}, {6, 0}, :white)

      # Queenside castling
      assert {:ok, :castle_queenside} = MoveValidator.validate_move(board, {4, 0}, {2, 0}, :white)
    end

    test "validates en passant" do
      # Create a board state with en passant possibility
      board = %Board{
        squares: %{
          {3, 4} => {:white, :pawn},
          {4, 4} => {:black, :pawn}
        },
        turn: :white,
        en_passant_target: {4, 3}
      }

      # En passant capture
      assert {:ok, :en_passant} = MoveValidator.validate_move(board, {3, 4}, {4, 3}, :white)
    end

    test "detects if move would result in check" do
      # Create a board where a move would put own king in check
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {4, 1} => {:white, :pawn},
          {4, 7} => {:black, :rook}
        },
        turn: :white
      }

      # Moving the pawn would open the king to check
      assert {:error, :would_result_in_check} =
               MoveValidator.validate_move(board, {4, 1}, {3, 2}, :white)
    end
  end

  describe "valid_moves/2" do
    test "returns all valid moves for a piece" do
      board = Board.new()

      # Valid moves for white knight at starting position
      valid_moves = MoveValidator.valid_moves(board, {1, 0})
      assert Enum.member?(valid_moves, {0, 2})
      assert Enum.member?(valid_moves, {2, 2})
      assert length(valid_moves) == 2

      # Valid moves for white pawn at starting position
      valid_moves = MoveValidator.valid_moves(board, {4, 1})
      assert Enum.member?(valid_moves, {4, 2})
      assert Enum.member?(valid_moves, {4, 3})
      assert length(valid_moves) == 2
    end

    test "returns empty list for empty square" do
      board = Board.new()
      assert MoveValidator.valid_moves(board, {4, 4}) == []
    end
  end

  describe "is_square_attacked?/3" do
    test "detects squares attacked by pawns" do
      board = %Board{
        squares: %{
          {3, 3} => {:white, :pawn}
        }
      }

      # Squares diagonally ahead of white pawn are attacked
      assert MoveValidator.is_square_attacked?(board, {2, 4}, :white)
      assert MoveValidator.is_square_attacked?(board, {4, 4}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {3, 4}, :white)
      refute MoveValidator.is_square_attacked?(board, {5, 5}, :white)
    end

    test "detects squares attacked by knights" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :knight}
        }
      }

      # L-shaped moves from the knight are attacked
      assert MoveValidator.is_square_attacked?(board, {2, 5}, :white)
      assert MoveValidator.is_square_attacked?(board, {3, 6}, :white)
      assert MoveValidator.is_square_attacked?(board, {5, 6}, :white)
      assert MoveValidator.is_square_attacked?(board, {6, 5}, :white)
      assert MoveValidator.is_square_attacked?(board, {6, 3}, :white)
      assert MoveValidator.is_square_attacked?(board, {5, 2}, :white)
      assert MoveValidator.is_square_attacked?(board, {3, 2}, :white)
      assert MoveValidator.is_square_attacked?(board, {2, 3}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {4, 5}, :white)
      refute MoveValidator.is_square_attacked?(board, {0, 0}, :white)
    end

    test "detects squares attacked by bishops" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :bishop}
        }
      }

      # Diagonal squares are attacked
      assert MoveValidator.is_square_attacked?(board, {2, 2}, :white)
      assert MoveValidator.is_square_attacked?(board, {6, 6}, :white)
      assert MoveValidator.is_square_attacked?(board, {2, 6}, :white)
      assert MoveValidator.is_square_attacked?(board, {6, 2}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {4, 5}, :white)
      # Testing opposite color
      refute MoveValidator.is_square_attacked?(board, {5, 5}, :black)
    end

    test "detects squares attacked by rooks" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :rook}
        }
      }

      # Horizontal and vertical squares are attacked
      assert MoveValidator.is_square_attacked?(board, {4, 0}, :white)
      assert MoveValidator.is_square_attacked?(board, {4, 7}, :white)
      assert MoveValidator.is_square_attacked?(board, {0, 4}, :white)
      assert MoveValidator.is_square_attacked?(board, {7, 4}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {5, 5}, :white)
      refute MoveValidator.is_square_attacked?(board, {3, 3}, :white)
    end

    test "detects squares attacked by queens" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :queen}
        }
      }

      # Horizontal, vertical, and diagonal squares are attacked
      assert MoveValidator.is_square_attacked?(board, {4, 0}, :white)
      assert MoveValidator.is_square_attacked?(board, {0, 4}, :white)
      assert MoveValidator.is_square_attacked?(board, {2, 2}, :white)
      assert MoveValidator.is_square_attacked?(board, {6, 6}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {5, 6}, :white)
      refute MoveValidator.is_square_attacked?(board, {6, 5}, :white)
    end

    test "detects squares attacked by kings" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :king}
        }
      }

      # Adjacent squares are attacked
      assert MoveValidator.is_square_attacked?(board, {3, 3}, :white)
      assert MoveValidator.is_square_attacked?(board, {3, 4}, :white)
      assert MoveValidator.is_square_attacked?(board, {3, 5}, :white)
      assert MoveValidator.is_square_attacked?(board, {4, 3}, :white)
      assert MoveValidator.is_square_attacked?(board, {4, 5}, :white)
      assert MoveValidator.is_square_attacked?(board, {5, 3}, :white)
      assert MoveValidator.is_square_attacked?(board, {5, 4}, :white)
      assert MoveValidator.is_square_attacked?(board, {5, 5}, :white)

      # Other squares are not attacked
      refute MoveValidator.is_square_attacked?(board, {2, 2}, :white)
      refute MoveValidator.is_square_attacked?(board, {4, 2}, :white)
    end

    test "handles pieces blocking attacks" do
      board = %Board{
        squares: %{
          {0, 0} => {:white, :rook},
          {0, 3} => {:white, :pawn}
        }
      }

      # Square behind the pawn is not attacked by the rook
      assert MoveValidator.is_square_attacked?(board, {0, 2}, :white)
      assert MoveValidator.is_square_attacked?(board, {0, 1}, :white)
      refute MoveValidator.is_square_attacked?(board, {0, 4}, :white)
      refute MoveValidator.is_square_attacked?(board, {0, 7}, :white)
    end
  end
end
