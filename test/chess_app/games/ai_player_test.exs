defmodule ChessApp.Games.AIPlayerTest do
  use ExUnit.Case, async: true
  alias ChessApp.Games.{Board, AIPlayer}

  describe "select_move/3" do
    test "always returns a valid move" do
      board = Board.new()
      {from, to, promotion_piece} = AIPlayer.select_move(board, :white, 1)

      # Check that returned values are within the board coordinates
      assert from != nil
      assert to != nil
      assert elem(from, 0) in 0..7
      assert elem(from, 1) in 0..7
      assert elem(to, 0) in 0..7
      assert elem(to, 1) in 0..7

      # Check that the promotion piece is valid when provided
      if promotion_piece != nil do
        assert promotion_piece in [:queen, :rook, :bishop, :knight]
      end
    end

    test "selects different moves at different difficulty levels" do
      board = Board.new()

      # Get moves at different difficulty levels
      move_easy = AIPlayer.select_move(board, :white, 1)
      move_medium = AIPlayer.select_move(board, :white, 2)
      move_hard = AIPlayer.select_move(board, :white, 3)

      # This test might occasionally fail if the AI happens to choose
      # the same move at different difficulties, but it should be rare
      assert move_easy != move_medium || move_medium != move_hard
    end

    test "avoids obviously bad moves" do
      # Create a board with a vulnerable queen
      board = %Board{
        squares: %{
          {4, 1} => {:white, :queen},
          {2, 3} => {:black, :pawn}
        },
        turn: :black
      }

      # Force the AI to evaluate only specific candidate moves
      # This makes the test more deterministic
      moves = [
        {{2, 3}, {4, 1}, nil},  # Pawn captures queen
        {{2, 3}, {2, 2}, nil}   # Pawn advances (ignoring queen)
      ]

      # Directly use our evaluation logic to select the best move
      {best_move, _score} = AIPlayer.evaluate_candidate_moves(board, moves, :black, 3)

      {from, to, _} = best_move
      assert from == {2, 3}
      assert to == {4, 1}  # Should capture the queen
    end

    test "prefers checkmate when available" do
      # Create a board where checkmate is possible in one move
      board = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {7, 1} => {:black, :queen},  # Queen can move to deliver checkmate
          {7, 0} => {:black, :rook}
        },
        turn: :black
      }

      # Force the AI to evaluate only specific candidate moves
      # This makes the test more deterministic
      moves = [
        {{7, 1}, {4, 1}, nil},  # Queen to e1 (checkmate)
        {{7, 0}, {6, 0}, nil}   # Rook move (not checkmate)
      ]

      # Directly use our evaluation logic to select the best move
      {best_move, _score} = AIPlayer.evaluate_candidate_moves(board, moves, :black, 3)

      {from, to, _} = best_move
      assert from == {7, 1}
      assert to == {4, 1}
    end
  end

  describe "evaluate_position/2" do
    test "correctly evaluates material advantage" do
      # White has an extra queen
      board_white_advantage = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {4, 7} => {:black, :king},
          {3, 3} => {:white, :queen}
        }
      }

      # Black has an extra queen
      board_black_advantage = %Board{
        squares: %{
          {4, 0} => {:white, :king},
          {4, 7} => {:black, :king},
          {3, 3} => {:black, :queen}
        }
      }

      white_score = AIPlayer.evaluate_position(board_white_advantage, :white)
      black_score = AIPlayer.evaluate_position(board_black_advantage, :white)

      assert white_score > 0
      assert black_score < 0
      assert white_score > black_score
    end

    test "values central pawn structure" do
      # White has central pawns
      board_central_white = %Board{
        squares: %{
          {3, 3} => {:white, :pawn},
          {4, 3} => {:white, :pawn}
        }
      }

      # White has edge pawns
      board_edge_white = %Board{
        squares: %{
          {0, 3} => {:white, :pawn},
          {7, 3} => {:white, :pawn}
        }
      }

      central_score = AIPlayer.evaluate_position(board_central_white, :white)
      edge_score = AIPlayer.evaluate_position(board_edge_white, :white)

      assert central_score > edge_score
    end
  end

  describe "minimax/5" do
    test "returns a score value" do
      board = Board.new()
      score = AIPlayer.minimax(board, 2, -100000, 100000, :white)

      # The score should be a number
      assert is_number(score)
    end

    test "identifies checkmate positions correctly" do
      # Create a checkmate position (black is checkmated)
      checkmate_board = %Board{
        squares: %{
          {4, 0} => {:black, :king},
          {0, 0} => {:white, :rook},
          {0, 1} => {:white, :rook}
        },
        turn: :black
      }

      # Black is checkmated, score should be very negative (bad for black)
      score = AIPlayer.evaluate_position(checkmate_board, :black)

      assert score < -10000
    end
  end
end
