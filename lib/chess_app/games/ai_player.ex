defmodule ChessApp.Games.AIPlayer do
  @moduledoc """
  Provides AI opponent functionality for single-player chess games.

  This module implements a basic chess AI using the minimax algorithm with
  alpha-beta pruning. The AI evaluates positions based on material value,
  piece position, and basic strategic considerations.
  """

  alias ChessApp.Games.{Board, MoveValidator}

  @piece_values %{
    pawn: 100,
    knight: 320,
    bishop: 330,
    rook: 500,
    queen: 900,
    king: 20000
  }

  @doc """
  Selects the best move for the AI to play based on the current board state.

  ## Parameters

    * `board` - The current board state
    * `color` - The color the AI is playing (:white or :black)
    * `difficulty` - The AI difficulty level (1-3, where 3 is hardest)

  ## Returns

    * `{from, to, promotion_piece}` - The selected move coordinates and optional promotion piece
  """
  def select_move(board, color, difficulty \\ 2) do
    # Determine search depth based on difficulty
    depth = case difficulty do
      1 -> 2
      2 -> 3
      3 -> 4
      _ -> 3
    end

    # Get all valid moves for the AI's pieces
    all_moves = generate_all_valid_moves(board, color)

    # Start with a random move as fallback
    best_move = Enum.random(all_moves)

    # For material-focused easy strategy, just sort by immediate capture value
    if difficulty == 1 do
      # Find the move with highest immediate material gain
      {best_move, _} = Enum.reduce(all_moves, {best_move, -1000}, fn move = {from, to, _}, {current_best, current_value} ->
        capture_value = immediate_capture_value(board, from, to)
        if capture_value > current_value do
          {move, capture_value}
        else
          {current_best, current_value}
        end
      end)

      best_move
    else
      # For deeper search, use minimax
      best_score = -100000
      alpha = -100000
      beta = 100000

      # For each possible move
      {best_move, _} = Enum.reduce(all_moves, {best_move, best_score}, fn move, {current_best, current_score} ->
        # Make the move on a copy of the board
        {from, to, promotion_piece} = move
        move_type = move_type(from, to, board, color)

        # Skip invalid moves
        if move_type == :invalid do
          {current_best, current_score}
        else
          case Board.make_move(board, from, to, move_type, promotion_piece) do
            {:ok, new_board} ->
              # Evaluate the position after the move using minimax
              # The negative is because we're looking from opponent's perspective
              score = -minimax(new_board, depth - 1, alpha, beta, opposite_color(color))

              # Keep track of the best move found
              if score > current_score do
                {move, score}
              else
                {current_best, current_score}
              end

            _ ->
              # If the move is invalid, keep the current best
              {current_best, current_score}
          end
        end
      end)

      best_move
    end
  end

  # Get immediate capture value (used for easy difficulty)
  defp immediate_capture_value(board, from, to) do
    # If capturing a piece, return its value
    case Board.piece_at(board, to) do
      {_color, piece_type} ->
        value_of(piece_type)
      nil ->
        # Check for checkmate (very high value)
        # This is simplified and only checks direct checkmates
        piece = Board.piece_at(board, from)

        # Check if the move would be a checkmate
        if could_be_checkmate?(board, from, to, piece) do
          10000  # Very high value to prioritize checkmate
        else
          # Favor center control for pawns
          case piece do
            {_, :pawn} ->
              {to_file, to_rank} = to
              if to_file >= 2 && to_file <= 5 && to_rank >= 2 && to_rank <= 5 do
                10  # Small bonus for central control
              else
                0
              end
            _ -> 0
          end
        end
    end
  end

  # Simple check for potential checkmate
  defp could_be_checkmate?(board, from, to, {attacker_color, _}) do
    # Find the opponent's king
    opponent_color = opposite_color(attacker_color)
    king_pos = find_king(board, opponent_color)

    # Skip if we can't find the king
    if king_pos do
      # Simulate the move
      move_type = move_type(from, to, board, attacker_color)

      if move_type != :invalid do
        case Board.make_move(board, from, to, move_type) do
          {:ok, new_board} ->
            # Check if king is in check and has no valid moves
            king_in_check?(new_board, opponent_color) &&
            !has_valid_moves?(new_board, opponent_color)
          _ -> false
        end
      else
        false
      end
    else
      false
    end
  end

  @doc """
  Implements the minimax algorithm with alpha-beta pruning to evaluate positions.

  ## Parameters

    * `board` - The current board state
    * `depth` - How many moves ahead to search
    * `alpha` - Alpha value for pruning
    * `beta` - Beta value for pruning
    * `color` - Whose turn it is (:white or :black)

  ## Returns

    * Score value for the position
  """
  def minimax(board, depth, alpha, beta, color) do
    # Base case: if we've reached maximum depth or game is over
    if depth == 0 || game_over?(board, color) do
      evaluate_position(board, color)
    else
      # Generate all valid moves for the current player
      moves = generate_all_valid_moves(board, color)

      # If there are no valid moves, return a position evaluation
      if Enum.empty?(moves) do
        evaluate_position(board, color)
      else
        do_minimax(board, depth, alpha, beta, color, moves)
      end
    end
  end

  # Implementation of minimax algorithm
  defp do_minimax(board, depth, alpha, beta, color, moves) do
    # Initialize values depending on whose turn it is
    {best_score, new_alpha, new_beta} = if color == :white do
      {-100000, alpha, beta} # Maximizing player
    else
      {100000, alpha, beta}  # Minimizing player
    end

    Enum.reduce_while(moves, {best_score, new_alpha, new_beta}, fn {from, to, promotion_piece}, {current_best, a, b} ->
      # Make the move
      move_type = move_type(from, to, board, color)

      if move_type == :invalid do
        {:cont, {current_best, a, b}}
      else
        case Board.make_move(board, from, to, move_type, promotion_piece) do
          {:ok, new_board} ->
            # Recursively evaluate the position
            score = minimax(new_board, depth - 1, a, b, opposite_color(color))

            # Update best score and alpha/beta values
            {new_best, new_a, new_b} = if color == :white do
              # Maximizing player
              {max(current_best, score), max(a, score), b}
            else
              # Minimizing player
              {min(current_best, score), a, min(b, score)}
            end

            # Alpha-beta pruning
            if new_a >= new_b do
              {:halt, {new_best, new_a, new_b}} # Prune the branch
            else
              {:cont, {new_best, new_a, new_b}}
            end

          _ ->
            # If the move is invalid, continue with current best
            {:cont, {current_best, a, b}}
        end
      end
    end)
    |> elem(0) # Extract the best score
  end

  @doc """
  Evaluates a chess position, returning a numerical score.
  Positive scores favor white, negative scores favor black.

  ## Parameters

    * `board` - The board state to evaluate
    * `color` - The color to evaluate the position for (not used in basic implementation)

  ## Returns

    * Numerical score of the position
  """
  def evaluate_position(board, color) do
    # Check for checkmate conditions first
    if king_in_check?(board, color) && !has_valid_moves?(board, color) do
      # Checkmate, very bad for the current player
      if color == :white, do: -50000, else: 50000
    else
      # Continue with regular evaluation
      material_score = evaluate_material(board)
      positional_score = evaluate_piece_positions(board)
      material_score + positional_score
    end
  end

  # Evaluate endgame conditions
  defp evaluate_endgame(board, color) do
    cond do
      # Check if the current player is in checkmate
      king_in_check?(board, color) && !has_valid_moves?(board, color) ->
        if color == :white, do: -50000, else: 50000

      # Check if the current player is in stalemate
      !king_in_check?(board, color) && !has_valid_moves?(board, color) ->
        0  # Stalemate is a draw

      true -> 0
    end
  end

  @doc """
  Evaluates a specific set of candidate moves and returns the best one.
  Used primarily for testing.
  """
  def evaluate_candidate_moves(board, candidate_moves, color, depth) do
    best_score = -100000
    best_move = Enum.at(candidate_moves, 0)

    Enum.reduce(candidate_moves, {best_move, best_score}, fn move, {current_best, current_score} ->
      # Make the move
      {from, to, promotion_piece} = move
      move_type = move_type(from, to, board, color)

      # Skip invalid moves
      if move_type == :invalid do
        {current_best, current_score}
      else
        case Board.make_move(board, from, to, move_type, promotion_piece) do
          {:ok, new_board} ->
            # Evaluate position after move
            score = -minimax(new_board, depth - 1, -100000, 100000, opposite_color(color))

            # Keep track of best move
            if score > current_score do
              {move, score}
            else
              {current_best, current_score}
            end

          _ ->
            {current_best, current_score}
        end
      end
    end)
  end

  # Evaluate board based on material (piece values)
  defp evaluate_material(board) do
    Enum.reduce(board.squares, 0, fn {_pos, piece}, score ->
      score + piece_value(piece)
    end)
  end

  # Piece values (positive for white, negative for black)
  defp piece_value({:white, piece_type}), do: value_of(piece_type)
  defp piece_value({:black, piece_type}), do: -value_of(piece_type)
  defp piece_value(_), do: 0

  defp value_of(:pawn), do: @piece_values.pawn
  defp value_of(:knight), do: @piece_values.knight
  defp value_of(:bishop), do: @piece_values.bishop
  defp value_of(:rook), do: @piece_values.rook
  defp value_of(:queen), do: @piece_values.queen
  defp value_of(:king), do: @piece_values.king

  # Evaluate positional advantages (piece-square tables)
  defp evaluate_piece_positions(board) do
    Enum.reduce(board.squares, 0, fn {pos, piece}, score ->
      score + position_value(piece, pos)
    end)
  end

  # Position values - more sophisticated version
  defp position_value({:white, :pawn}, {file, rank}) do
    # Pawns are more valuable as they advance
    base_value = (rank - 1) * 10

    # Add significant bonus for central pawns
    center_bonus = cond do
      file >= 3 && file <= 4 -> 20  # Central files (d and e)
      file >= 2 && file <= 5 -> 10  # Semi-central files (c and f)
      true -> 0                     # Edge files
    end

    base_value + center_bonus
  end

  defp position_value({:black, :pawn}, {file, rank}) do
    # Pawns are more valuable as they advance (for black, lower ranks are better)
    base_value = (6 - rank) * -10

    # Add significant bonus for central pawns
    center_bonus = cond do
      file >= 3 && file <= 4 -> -20  # Central files (d and e)
      file >= 2 && file <= 5 -> -10  # Semi-central files (c and f)
      true -> 0                      # Edge files
    end

    base_value + center_bonus
  end

  defp position_value({:white, :knight}, {file, rank}) do
    # Knights are better in the center
    cond do
      file >= 2 && file <= 5 && rank >= 2 && rank <= 5 -> 30  # Center
      file >= 1 && file <= 6 && rank >= 1 && rank <= 6 -> 15  # Near center
      true -> 0  # Edges
    end
  end

  defp position_value({:black, :knight}, {file, rank}) do
    # Knights are better in the center
    cond do
      file >= 2 && file <= 5 && rank >= 2 && rank <= 5 -> -30  # Center
      file >= 1 && file <= 6 && rank >= 1 && rank <= 6 -> -15  # Near center
      true -> 0  # Edges
    end
  end

  defp position_value({:white, :bishop}, {file, rank}) do
    # Bishops benefit from diagonals
    cond do
      file >= 2 && file <= 5 && rank >= 2 && rank <= 5 -> 15  # Center control
      file >= 1 && file <= 6 && rank >= 1 && rank <= 6 -> 10  # Development
      true -> 0
    end
  end

  defp position_value({:black, :bishop}, {file, rank}) do
    # Bishops benefit from diagonals
    cond do
      file >= 2 && file <= 5 && rank >= 2 && rank <= 5 -> -15  # Center control
      file >= 1 && file <= 6 && rank >= 1 && rank <= 6 -> -10  # Development
      true -> 0
    end
  end

  defp position_value({:white, :queen}, {file, rank}) do
    # Queens benefit from central position
    if file >= 2 && file <= 5 && rank >= 2 && rank <= 5, do: 10, else: 0
  end

  defp position_value({:black, :queen}, {file, rank}) do
    # Queens benefit from central position
    if file >= 2 && file <= 5 && rank >= 2 && rank <= 5, do: -10, else: 0
  end

  defp position_value({:white, :king}, {file, _rank}) do
    # Kings prefer the corners in the opening/middlegame
    if file <= 1 || file >= 6, do: 10, else: 0
  end

  defp position_value({:black, :king}, {file, _rank}) do
    # Kings prefer the corners in the opening/middlegame
    if file <= 1 || file >= 6, do: -10, else: 0
  end

  defp position_value(_, _), do: 0

  # Generate all valid moves for a given color
  defp generate_all_valid_moves(board, color) do
    board.squares
    |> Enum.filter(fn {_pos, piece} ->
        is_tuple(piece) && elem(piece, 0) == color
      end)
    |> Enum.flat_map(fn {from, _piece} ->
      # Get all valid destinations for this piece
      board
      |> MoveValidator.valid_moves(from)
      |> Enum.map(fn to ->
        # Check if this is a pawn promotion move
        promotion_piece = needs_promotion?(board, from, to)
        {from, to, promotion_piece}
      end)
    end)
  end

  # Check if a move would result in pawn promotion
  defp needs_promotion?(board, from, to) do
    piece = Board.piece_at(board, from)

    case piece do
      {:white, :pawn} ->
        {_, to_rank} = to
        if to_rank == 7, do: :queen, else: nil

      {:black, :pawn} ->
        {_, to_rank} = to
        if to_rank == 0, do: :queen, else: nil

      _ ->
        nil
    end
  end

  # Determine the move type (normal, capture, etc.)
  defp move_type(from, to, board, color \\ nil) do
    playing_color = color || board.turn

    case MoveValidator.validate_move(board, from, to, playing_color) do
      {:ok, move_type} -> move_type
      {:error, _} -> :invalid
    end
  end

  # Is the game over?
  defp game_over?(board, color) do
    # Game is over if the current player has no valid moves
    !has_valid_moves?(board, color) ||
    insufficient_material?(board) ||
    fifty_move_rule?(board)
  end

  # Helper to check if a player has valid moves
  defp has_valid_moves?(board, color) do
    # Find all pieces of the given color
    pieces = board.squares
      |> Enum.filter(fn {_pos, piece} ->
          is_tuple(piece) && elem(piece, 0) == color
        end)
      |> Enum.map(fn {pos, _piece} -> pos end)

    # Check if any piece has valid moves
    Enum.any?(pieces, fn pos ->
      MoveValidator.valid_moves(board, pos) != []
    end)
  end

  # Check if a king is in check
  defp king_in_check?(board, color) do
    # Find king position
    king_pos = find_king(board, color)

    # Check if it's under attack
    king_pos != nil && MoveValidator.is_square_attacked?(board, king_pos, opposite_color(color))
  end

  # Find the king's position
  defp find_king(board, color) do
    Enum.find_value(board.squares, fn
      {{file, rank}, {^color, :king}} -> {file, rank}
      _ -> nil
    end)
  end

  # Check for insufficient material draw
  defp insufficient_material?(board) do
    pieces = Map.values(board.squares)

    # Only kings left
    length(pieces) == 2 ||
    # King and bishop/knight vs king
    (length(pieces) == 3 &&
     Enum.count(pieces, fn piece ->
       is_tuple(piece) && elem(piece, 1) in [:bishop, :knight]
     end) == 1)
  end

  # Check for fifty move rule
  defp fifty_move_rule?(board) do
    board.halfmove_clock >= 100
  end

  # Get the opposite color
  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
