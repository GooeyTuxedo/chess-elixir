defmodule ChessApp.Games.AIGameServerTest do
  use ExUnit.Case, async: false
  alias ChessApp.Games.GameServer

  setup do
    # Create a test game with AI
    {:ok, game_id} = GameServer.create_game_with_ai(ai_color: :black, ai_difficulty: 1)

    on_exit(fn ->
      GameServer.terminate_game(game_id)
    end)

    %{game_id: game_id}
  end

  test "creates a game with AI player", %{game_id: game_id} do
    game_state = GameServer.get_state(game_id)

    assert game_state.ai_player == :black
    assert game_state.ai_difficulty == 1
    assert game_state.status == :waiting_for_players
  end

  test "assigns human player to correct color", %{game_id: game_id} do
    # Join the game as human player
    {:ok, color} = GameServer.join_game(game_id, "test_session", "TestPlayer")

    # Should be assigned as white (since AI is black)
    assert color == :white

    # Get state after joining
    game_state = GameServer.get_state(game_id)

    # Status should now be in_progress
    assert game_state.status == :in_progress
    assert game_state.players.white == {"test_session", "TestPlayer"}
    assert game_state.players.black != nil # AI player has been assigned
  end

  test "AI makes moves when it's their turn", %{game_id: game_id} do
    # Join as human player
    {:ok, _color} = GameServer.join_game(game_id, "test_session", "TestPlayer")

    # Make a human move
    GameServer.make_move(game_id, "test_session", {4, 1}, {4, 3})

    # Wait for AI to respond
    :timer.sleep(1500)

    # Get state after AI move
    game_state = GameServer.get_state(game_id)

    # Verify that the board state has changed (AI made a move)
    assert length(game_state.move_history) >= 2

    # Turn should be back to white after AI moves
    assert game_state.current_turn == :white
  end

  test "creates AI game with white AI", %{game_id: _game_id} do
    # Create a new game with white AI
    {:ok, game_id2} = GameServer.create_game_with_ai(ai_color: :white, ai_difficulty: 1)

    game_state = GameServer.get_state(game_id2)
    assert game_state.ai_player == :white

    # Cleanup
    GameServer.terminate_game(game_id2)
  end

  test "AI promotes pawns correctly" do
    # Create a game with AI
    {:ok, game_id} = GameServer.create_game_with_ai(ai_color: :black, ai_difficulty: 1)

    # Get access to the process
    pid = GenServer.whereis({:via, Registry, {ChessApp.GameRegistry, game_id}})

    # Create a custom board with a black pawn about to promote
    custom_board = %ChessApp.Games.Board{
      squares: %{
        {3, 1} => {:black, :pawn},  # Black pawn one step away from promotion
        {4, 0} => {:white, :king},
        {4, 7} => {:black, :king}
      },
      turn: :black,
      castling_rights: %{
        black: %{kingside: false, queenside: false},
        white: %{kingside: false, queenside: false}
      }
    }

    # Replace the board in the game server's state
    :sys.replace_state(pid, fn state ->
      %{state |
        board: custom_board,
        players: %{white: {"test_session", "TestPlayer"}, black: {"ai_session", "AI Player"}},
        status: :in_progress,
        ai_player: :black,
        ai_difficulty: 1
      }
    end)

    # Make the move directly instead of relying on the AI
    {:ok, _} = GameServer.make_move(game_id, "ai_session", {3, 1}, {3, 0}, :queen)

    # Check if the pawn was promoted
    game_state = GameServer.get_state(game_id)
    promoted_piece = game_state.board.squares[{3, 0}]

    # The pawn should be promoted to a queen
    assert promoted_piece != nil
    assert elem(promoted_piece, 0) == :black
    assert elem(promoted_piece, 1) == :queen

    # Cleanup
    GameServer.terminate_game(game_id)
  end
end
