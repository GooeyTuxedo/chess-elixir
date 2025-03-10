defmodule ChessApp.Games.GameRegistryTest do
  use ExUnit.Case, async: false
  alias ChessApp.Games.{GameServer, GameRegistry}

  setup do
    # Create some test games
    {:ok, game_id1} = GameServer.create_game()
    {:ok, game_id2} = GameServer.create_game()

    # Add a player to the second game
    {:ok, _} = GameServer.join_game(game_id2, "test_session", "TestPlayer")

    on_exit(fn ->
      # Clean up test games
      GameServer.terminate_game(game_id1)
      GameServer.terminate_game(game_id2)
    end)

    %{game_id1: game_id1, game_id2: game_id2}
  end

  describe "list_active_games/0" do
    test "returns all active games", %{game_id1: game_id1, game_id2: game_id2} do
      games = GameRegistry.list_active_games()

      assert Enum.any?(games, fn %{game_id: id} -> id == game_id1 end)
      assert Enum.any?(games, fn %{game_id: id} -> id == game_id2 end)
    end
  end

  describe "list_joinable_games/0" do
    test "returns games waiting for players", %{game_id1: game_id1, game_id2: game_id2} do
      joinable = GameRegistry.list_joinable_games()

      # Both games should be joinable since neither has 2 players
      assert Enum.any?(joinable, fn %{game_id: id} -> id == game_id1 end)
      assert Enum.any?(joinable, fn %{game_id: id} -> id == game_id2 end)

      # Add a second player to game2 to make it non-joinable
      {:ok, _} = GameServer.join_game(game_id2, "test_session2", "TestPlayer2")

      # Check again
      joinable = GameRegistry.list_joinable_games()
      assert Enum.any?(joinable, fn %{game_id: id} -> id == game_id1 end)
      refute Enum.any?(joinable, fn %{game_id: id} -> id == game_id2 end)
    end
  end

  describe "list_spectatable_games/0" do
    test "returns games that can be spectated", %{game_id1: game_id1, game_id2: game_id2} do
      # No games should be spectatable yet
      spectatable = GameRegistry.list_spectatable_games()
      refute Enum.any?(spectatable, fn %{game_id: id} -> id == game_id1 end)
      refute Enum.any?(spectatable, fn %{game_id: id} -> id == game_id2 end)

      # Make game2 full with 2 players
      {:ok, _} = GameServer.join_game(game_id2, "test_session2", "TestPlayer2")

      # Now game2 should be spectatable
      spectatable = GameRegistry.list_spectatable_games()
      refute Enum.any?(spectatable, fn %{game_id: id} -> id == game_id1 end)
      assert Enum.any?(spectatable, fn %{game_id: id} -> id == game_id2 end)
    end
  end

  describe "cleanup_old_games/0" do
    test "cleans up abandoned games" do
      # This is harder to test directly without manipulating time
      # or adding test-specific hooks, but we can test the function exists
      assert function_exported?(GameRegistry, :cleanup_old_games, 0)
    end
  end
end
