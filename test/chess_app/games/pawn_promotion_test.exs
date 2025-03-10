defmodule ChessApp.Games.PawnPromotionTest do
  use ExUnit.Case, async: false
  alias ChessApp.Games.{Board, GameServer}

  setup do
    # Create a custom board with a pawn about to promote
    board = %Board{
      squares: %{
        {3, 6} => {:white, :pawn},  # White pawn one step away from promotion
        {4, 0} => {:white, :king},
        {4, 7} => {:black, :king}
      },
      turn: :white,
      castling_rights: %{
        white: %{kingside: false, queenside: false},
        black: %{kingside: false, queenside: false}
      }
    }

    # Create a test game with this board
    {:ok, game_id} = GameServer.create_game()

    # Hack: We need to replace the board in the game server
    # This is for testing only and wouldn't be done in production
    pid = GenServer.whereis({:via, Registry, {ChessApp.GameRegistry, game_id}})
    :sys.replace_state(pid, fn state ->
      %{state | board: board}
    end)

    # Add players
    {:ok, :white} = GameServer.join_game(game_id, "white_player", "White")
    {:ok, :black} = GameServer.join_game(game_id, "black_player", "Black")

    on_exit(fn ->
      GameServer.terminate_game(game_id)
    end)

    %{game_id: game_id}
  end

  describe "pawn promotion" do
    test "requires promotion piece when pawn reaches last rank", %{game_id: game_id} do
      # Try to move pawn to promotion square without specifying promotion piece
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7})

      # Should return error asking for promotion piece
      assert {:error, :need_promotion_selection, {3, 6}, {3, 7}} = result
    end

    test "promotes pawn when piece is specified", %{game_id: game_id} do
      # Move pawn to promotion square with specified promotion piece
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7}, :queen)

      assert {:ok, :promotion} = result

      # Check that the pawn was promoted
      game_state = GameServer.get_state(game_id)
      assert game_state.board.squares[{3, 7}] == {:white, :queen}
      assert game_state.board.squares[{3, 6}] == nil

      # Check that turn changed
      assert game_state.board.turn == :black
    end

    test "can promote to knight", %{game_id: game_id} do
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7}, :knight)

      assert {:ok, :promotion} = result

      game_state = GameServer.get_state(game_id)
      assert game_state.board.squares[{3, 7}] == {:white, :knight}
    end

    test "can promote to rook", %{game_id: game_id} do
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7}, :rook)

      assert {:ok, :promotion} = result

      game_state = GameServer.get_state(game_id)
      assert game_state.board.squares[{3, 7}] == {:white, :rook}
    end

    test "can promote to bishop", %{game_id: game_id} do
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7}, :bishop)

      assert {:ok, :promotion} = result

      game_state = GameServer.get_state(game_id)
      assert game_state.board.squares[{3, 7}] == {:white, :bishop}
    end

    test "cannot promote to invalid piece type", %{game_id: game_id} do
      # Try to promote to a king (not allowed in chess)
      result = GameServer.make_move(game_id, "white_player", {3, 6}, {3, 7}, :king)

      # Should return a specific error for invalid promotion piece
      assert result == {:error, :invalid_promotion_piece}
    end
  end
end
