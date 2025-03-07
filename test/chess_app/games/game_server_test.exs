defmodule ChessApp.Games.GameServerTest do
  use ExUnit.Case
  alias ChessApp.Games.GameServer

  setup do
    # Start a new game for each test
    {:ok, game_id} = GameServer.create_game()
    %{game_id: game_id}
  end

  describe "create_game/0" do
    test "creates a new game with unique ID" do
      {:ok, game_id1} = GameServer.create_game()
      {:ok, game_id2} = GameServer.create_game()

      assert is_binary(game_id1)
      assert is_binary(game_id2)
      assert game_id1 != game_id2
    end
  end

  describe "join_game/3" do
    test "allows two players to join a game", %{game_id: game_id} do
      assert {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")
      assert {:ok, :black} = GameServer.join_game(game_id, "player2_session", "Player 2")
    end

    test "returns error when game is full", %{game_id: game_id} do
      assert {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")
      assert {:ok, :black} = GameServer.join_game(game_id, "player2_session", "Player 2")
      assert {:error, :game_full} = GameServer.join_game(game_id, "player3_session", "Player 3")
    end

    test "returns same color when player rejoins game", %{game_id: game_id} do
      assert {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")
      assert {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")

      assert {:ok, :black} = GameServer.join_game(game_id, "player2_session", "Player 2")
      assert {:ok, :black} = GameServer.join_game(game_id, "player2_session", "Player 2")
    end
  end

  describe "get_state/1" do
    test "returns the current game state", %{game_id: game_id} do
      # Join a game to have some state changes
      {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")

      state = GameServer.get_state(game_id)

      assert state.game_id == game_id
      assert state.status == :waiting_for_players
      assert state.current_turn == :white
      assert state.players.white == {"player1_session", "Player 1"}
      assert state.players.black == nil
    end
  end

  describe "make_move/4" do
    setup %{game_id: game_id} do
      # Join both players to the game
      {:ok, :white} = GameServer.join_game(game_id, "player1_session", "Player 1")
      {:ok, :black} = GameServer.join_game(game_id, "player2_session", "Player 2")
      :ok
    end

    test "allows white player to make first move", %{game_id: game_id} do
      # White pawn moves forward two squares
      assert {:ok, _} = GameServer.make_move(game_id, "player1_session", {4, 1}, {4, 3})

      # Get state to verify the move was made
      state = GameServer.get_state(game_id)
      assert state.board.squares[{4, 1}] == nil
      assert state.board.squares[{4, 3}] == {:white, :pawn}
      assert state.current_turn == :black
    end

    test "prevents player from moving opponent's pieces", %{game_id: game_id} do
      # Black player tries to move white's piece
      assert {:error, _} = GameServer.make_move(game_id, "player2_session", {4, 1}, {4, 3})
    end

    test "prevents player from moving out of turn", %{game_id: game_id} do
      # White pawn moves forward
      assert {:ok, _} = GameServer.make_move(game_id, "player1_session", {4, 1}, {4, 3})

      # White tries to move again
      assert {:error, :not_your_turn} =
               GameServer.make_move(game_id, "player1_session", {5, 1}, {5, 3})
    end

    test "allows a complete exchange of moves", %{game_id: game_id} do
      # White's first move
      assert {:ok, _} = GameServer.make_move(game_id, "player1_session", {4, 1}, {4, 3})

      # Black's response
      assert {:ok, _} = GameServer.make_move(game_id, "player2_session", {4, 6}, {4, 4})

      # White's second move
      assert {:ok, _} = GameServer.make_move(game_id, "player1_session", {3, 0}, {7, 4})

      # Get state to verify moves
      state = GameServer.get_state(game_id)
      assert state.board.squares[{4, 3}] == {:white, :pawn}
      assert state.board.squares[{4, 4}] == {:black, :pawn}
      assert state.board.squares[{7, 4}] == {:white, :queen}
      assert state.current_turn == :black
    end

    test "prevents invalid moves", %{game_id: game_id} do
      # Attempt invalid pawn move
      assert {:error, _} = GameServer.make_move(game_id, "player1_session", {4, 1}, {4, 5})

      # Attempt invalid knight move
      assert {:error, _} = GameServer.make_move(game_id, "player1_session", {1, 0}, {1, 2})
    end
  end
end
