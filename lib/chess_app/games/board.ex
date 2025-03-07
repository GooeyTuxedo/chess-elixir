defmodule ChessApp.Games.Board do
  @moduledoc """
  Represents a chess board and handles board state.
  """

  @type position :: {0..7, 0..7}
  @type piece :: {color(), piece_type()}
  @type color :: :white | :black
  @type piece_type :: :pawn | :knight | :bishop | :rook | :queen | :king

  defstruct squares: %{},
            turn: :white,
            castling_rights: %{white: %{kingside: true, queenside: true},
                               black: %{kingside: true, queenside: true}},
            en_passant_target: nil,
            halfmove_clock: 0,
            fullmove_number: 1

  @doc """
  Creates a new board with pieces in their initial positions.
  """
  def new do
    %__MODULE__{
      squares: initial_position()
    }
  end

  @doc """
  Returns the piece at the given position, or nil if empty.
  """
  def piece_at(board, position) do
    Map.get(board.squares, position)
  end

  @doc """
  Returns the color of the piece at the given position, or nil if empty.
  """
  def color_at(board, position) do
    case piece_at(board, position) do
      {color, _} -> color
      nil -> nil
    end
  end

  @doc """
  Makes a move on the board.
  Returns {:ok, new_board} or {:error, reason}.
  """
  def make_move(board, from, to, move_type, promotion_piece \\ nil) do
    piece = piece_at(board, from)

    # Apply the move
    new_board = case move_type do
      :normal ->
        apply_normal_move(board, from, to)

      :capture ->
        apply_normal_move(board, from, to)

      :double_push ->
        # Set en passant target
        {file, rank} = to
        direction = if elem(piece, 0) == :white, do: -1, else: 1
        en_passant_target = {file, rank + direction}

        board
        |> apply_normal_move(from, to)
        |> Map.put(:en_passant_target, en_passant_target)

      :en_passant ->
        # Remove the captured pawn
        {to_file, to_rank} = to
        direction = if elem(piece, 0) == :white, do: -1, else: 1
        captured_position = {to_file, to_rank - direction}

        board
        |> apply_normal_move(from, to)
        |> update_in([Access.key(:squares)], &Map.delete(&1, captured_position))

      :castle_kingside ->
        # Move king and rook
        {_, king_rank} = from
        rook_from = {7, king_rank}
        rook_to = {5, king_rank}

        board
        |> apply_normal_move(from, to)  # Move king
        |> apply_normal_move(rook_from, rook_to)  # Move rook

      :castle_queenside ->
        # Move king and rook
        {_, king_rank} = from
        rook_from = {0, king_rank}
        rook_to = {3, king_rank}

        board
        |> apply_normal_move(from, to)  # Move king
        |> apply_normal_move(rook_from, rook_to)  # Move rook

      :promotion ->
        # Ensure a promotion piece was provided
        if promotion_piece do
          # Get the color from the original piece
          {color, _} = piece
          # Create the new piece with the provided promotion piece type
          promoted_piece = {color, promotion_piece}

          # Remove the pawn and add the new piece
          update_in(board, [Access.key(:squares)], fn squares ->
            squares
            |> Map.delete(from)
            |> Map.put(to, promoted_piece)
          end)
        else
          {:error, :promotion_piece_required}
        end
    end

    # Handle error case
    if is_tuple(new_board) and elem(new_board, 0) == :error do
      new_board
    else
      # Update castling rights if king or rook moved
      new_board = update_castling_rights(new_board, from, piece)

      # Reset en passant target on normal moves
      new_board = if move_type != :double_push do
        %{new_board | en_passant_target: nil}
      else
        new_board
      end

      # Update turn
      new_board = %{new_board | turn: opposite_color(board.turn)}

      # Update move counters
      new_board = update_move_counters(new_board, piece, move_type)

      {:ok, new_board}
    end
  end

  defp apply_normal_move(board, from, to) do
    piece = piece_at(board, from)

    update_in(board, [Access.key(:squares)], fn squares ->
      squares
      |> Map.delete(from)
      |> Map.put(to, piece)
    end)
  end

  defp update_castling_rights(board, {file, rank}, {color, piece_type}) do
    case {piece_type, file, rank} do
      # King moved
      {:king, 4, 0} when color == :white ->
        put_in(board, [Access.key(:castling_rights), Access.key(:white)],
               %{kingside: false, queenside: false})

      {:king, 4, 7} when color == :black ->
        put_in(board, [Access.key(:castling_rights), Access.key(:black)],
               %{kingside: false, queenside: false})

      # Kingside rook moved
      {:rook, 7, 0} when color == :white ->
        put_in(board, [Access.key(:castling_rights), Access.key(:white), Access.key(:kingside)], false)

      {:rook, 7, 7} when color == :black ->
        put_in(board, [Access.key(:castling_rights), Access.key(:black), Access.key(:kingside)], false)

      # Queenside rook moved
      {:rook, 0, 0} when color == :white ->
        put_in(board, [Access.key(:castling_rights), Access.key(:white), Access.key(:queenside)], false)

      {:rook, 0, 7} when color == :black ->
        put_in(board, [Access.key(:castling_rights), Access.key(:black), Access.key(:queenside)], false)

      # No castling rights affected
      _ ->
        board
    end
  end

  defp update_move_counters(board, {_, piece_type}, move_type) do
    # Reset halfmove clock on pawn moves and captures
    halfmove_clock = if piece_type == :pawn || move_type == :capture || move_type == :en_passant do
      0
    else
      board.halfmove_clock + 1
    end

    # Increment fullmove number on black's turn
    fullmove_number = if board.turn == :black do
      board.fullmove_number + 1
    else
      board.fullmove_number
    end

    %{board | halfmove_clock: halfmove_clock, fullmove_number: fullmove_number}
  end

  defp initial_position do
    # Create a map with starting positions for all pieces
    %{}
    |> place_pawns()
    |> place_pieces(:white)
    |> place_pieces(:black)
  end

  defp place_pawns(squares) do
    # Place white pawns on rank 1
    white_pawns = for file <- 0..7, do: {{file, 1}, {:white, :pawn}}

    # Place black pawns on rank 6
    black_pawns = for file <- 0..7, do: {{file, 6}, {:black, :pawn}}

    squares
    |> Map.merge(Map.new(white_pawns))
    |> Map.merge(Map.new(black_pawns))
  end

  defp place_pieces(squares, :white) do
    # Place white pieces on rank 0
    [
      {{0, 0}, {:white, :rook}},
      {{1, 0}, {:white, :knight}},
      {{2, 0}, {:white, :bishop}},
      {{3, 0}, {:white, :queen}},
      {{4, 0}, {:white, :king}},
      {{5, 0}, {:white, :bishop}},
      {{6, 0}, {:white, :knight}},
      {{7, 0}, {:white, :rook}}
    ]
    |> Map.new()
    |> Map.merge(squares)
  end

  defp place_pieces(squares, :black) do
    # Place black pieces on rank 7
    [
      {{0, 7}, {:black, :rook}},
      {{1, 7}, {:black, :knight}},
      {{2, 7}, {:black, :bishop}},
      {{3, 7}, {:black, :queen}},
      {{4, 7}, {:black, :king}},
      {{5, 7}, {:black, :bishop}},
      {{6, 7}, {:black, :knight}},
      {{7, 7}, {:black, :rook}}
    ]
    |> Map.new()
    |> Map.merge(squares)
  end

  defp opposite_color(:white), do: :black
  defp opposite_color(:black), do: :white
end
