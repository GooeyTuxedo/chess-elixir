defmodule ChessApp.Games.BoardTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.Board

  describe "new/0" do
    test "creates a board with all pieces in initial positions" do
      board = Board.new()

      # Check if white pieces are in correct positions
      assert board.squares[{0, 0}] == {:white, :rook}
      assert board.squares[{1, 0}] == {:white, :knight}
      assert board.squares[{2, 0}] == {:white, :bishop}
      assert board.squares[{3, 0}] == {:white, :queen}
      assert board.squares[{4, 0}] == {:white, :king}
      assert board.squares[{5, 0}] == {:white, :bishop}
      assert board.squares[{6, 0}] == {:white, :knight}
      assert board.squares[{7, 0}] == {:white, :rook}

      # Check white pawns
      for file <- 0..7 do
        assert board.squares[{file, 1}] == {:white, :pawn}
      end

      # Check if black pieces are in correct positions
      assert board.squares[{0, 7}] == {:black, :rook}
      assert board.squares[{1, 7}] == {:black, :knight}
      assert board.squares[{2, 7}] == {:black, :bishop}
      assert board.squares[{3, 7}] == {:black, :queen}
      assert board.squares[{4, 7}] == {:black, :king}
      assert board.squares[{5, 7}] == {:black, :bishop}
      assert board.squares[{6, 7}] == {:black, :knight}
      assert board.squares[{7, 7}] == {:black, :rook}

      # Check black pawns
      for file <- 0..7 do
        assert board.squares[{file, 6}] == {:black, :pawn}
      end

      # Check empty squares (just a few examples)
      assert board.squares[{0, 2}] == nil
      assert board.squares[{4, 4}] == nil
      assert board.squares[{7, 5}] == nil
    end

    test "starts with white's turn" do
      board = Board.new()
      assert board.turn == :white
    end

    test "starts with all castling rights" do
      board = Board.new()

      assert board.castling_rights == %{
               white: %{kingside: true, queenside: true},
               black: %{kingside: true, queenside: true}
             }
    end
  end

  describe "piece_at/2" do
    test "returns the piece at the given position" do
      board = Board.new()
      assert Board.piece_at(board, {0, 0}) == {:white, :rook}
      assert Board.piece_at(board, {4, 7}) == {:black, :king}
      assert Board.piece_at(board, {3, 3}) == nil
    end
  end

  describe "color_at/2" do
    test "returns the color of the piece at the given position" do
      board = Board.new()
      assert Board.color_at(board, {0, 0}) == :white
      assert Board.color_at(board, {4, 7}) == :black
      assert Board.color_at(board, {3, 3}) == nil
    end
  end

  describe "make_move/5" do
    test "performs a normal move correctly" do
      board = Board.new()
      {:ok, new_board} = Board.make_move(board, {4, 1}, {4, 3}, :double_push)

      assert new_board.squares[{4, 1}] == nil
      assert new_board.squares[{4, 3}] == {:white, :pawn}
      assert new_board.turn == :black
      assert new_board.en_passant_target == {4, 2}
    end

    test "handles capturing correctly" do
      board = %Board{
        squares: %{
          {4, 4} => {:white, :pawn},
          {5, 5} => {:black, :pawn}
        },
        turn: :white
      }

      {:ok, new_board} = Board.make_move(board, {4, 4}, {5, 5}, :capture)

      assert new_board.squares[{4, 4}] == nil
      assert new_board.squares[{5, 5}] == {:white, :pawn}
    end

    test "handles en passant capture correctly" do
      # Create a board state with en passant possibility
      board = %Board{
        squares: %{
          {4, 4} => {:white, :pawn},
          {5, 4} => {:black, :pawn}
        },
        turn: :white,
        en_passant_target: {5, 3}
      }

      {:ok, new_board} = Board.make_move(board, {4, 4}, {5, 3}, :en_passant)

      assert new_board.squares[{4, 4}] == nil
      # Captured pawn is removed
      assert new_board.squares[{5, 4}] == nil
      assert new_board.squares[{5, 3}] == {:white, :pawn}
    end

    test "updates castling rights when king moves" do
      board = Board.new()
      {:ok, new_board} = Board.make_move(board, {4, 0}, {4, 1}, :normal)

      assert new_board.castling_rights.white.kingside == false
      assert new_board.castling_rights.white.queenside == false
      assert new_board.castling_rights.black.kingside == true
      assert new_board.castling_rights.black.queenside == true
    end

    test "updates castling rights when rook moves" do
      board = Board.new()
      {:ok, new_board} = Board.make_move(board, {0, 0}, {0, 1}, :normal)

      assert new_board.castling_rights.white.kingside == true
      assert new_board.castling_rights.white.queenside == false
      assert new_board.castling_rights.black.kingside == true
      assert new_board.castling_rights.black.queenside == true
    end

    test "performs kingside castling correctly" do
      # Create a board state where castling is possible
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 0} => {:white, :rook}
        },
        turn: :white,
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      {:ok, new_board} = Board.make_move(board, {4, 0}, {6, 0}, :castle_kingside)

      assert new_board.squares[{4, 0}] == nil
      assert new_board.squares[{7, 0}] == nil
      assert new_board.squares[{6, 0}] == {:white, :king}
      assert new_board.squares[{5, 0}] == {:white, :rook}
    end

    test "performs queenside castling correctly" do
      # Create a board state where castling is possible
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {0, 0} => {:white, :rook}
        },
        turn: :white,
        castling_rights: %{
          white: %{kingside: true, queenside: true},
          black: %{kingside: true, queenside: true}
        }
      }

      {:ok, new_board} = Board.make_move(board, {4, 0}, {2, 0}, :castle_queenside)

      assert new_board.squares[{4, 0}] == nil
      assert new_board.squares[{0, 0}] == nil
      assert new_board.squares[{2, 0}] == {:white, :king}
      assert new_board.squares[{3, 0}] == {:white, :rook}
    end

    test "performs pawn promotion correctly" do
      # Create a board state where promotion is possible
      board = %Board{
        squares: %{
          {4, 6} => {:white, :pawn}
        },
        turn: :white
      }

      {:ok, new_board} = Board.make_move(board, {4, 6}, {4, 7}, :promotion, :queen)

      assert new_board.squares[{4, 6}] == nil
      assert new_board.squares[{4, 7}] == {:white, :queen}
    end
  end
end
