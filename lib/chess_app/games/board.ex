# lib/chess_app/games/board.ex
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
end
