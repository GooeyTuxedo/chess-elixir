defmodule ChessApp.Games.GameRegistry do
  @moduledoc """
  Manages a registry of active game sessions.
  Provides functions to track, list, and query available games.
  """

  alias ChessApp.Games.GameServer

  @doc """
  Returns a list of all active games with their metadata.
  """
  def list_active_games do
    # Get all game processes from the Registry
    Registry.select(ChessApp.GameRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {game_id, pid, _} ->
      # Get state for each game
      try do
        game_state = GameServer.get_state(game_id)

        # Create a map with essential game info
        %{
          game_id: game_id,
          status: game_state.status,
          players: %{
            white: player_info(game_state.players.white),
            black: player_info(game_state.players.black)
          },
          created_at: get_creation_time(pid),
          last_activity: get_last_activity(game_state)
        }
      rescue
        # Skip games that might be terminating
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn %{created_at: time} -> time end, {:desc, DateTime})
  end

  @doc """
  Returns a list of games available to join (waiting for players)
  """
  def list_joinable_games do
    list_active_games()
    |> Enum.filter(fn game ->
      game.status == :waiting_for_players &&
      (is_nil(game.players.black) || is_nil(game.players.white))
    end)
  end

  @doc """
  Returns a list of games available to spectate (in progress)
  """
  def list_spectatable_games do
    list_active_games()
    |> Enum.filter(fn game ->
      game.status in [:in_progress, :check_white, :check_black] &&
      !is_nil(game.players.white) &&
      !is_nil(game.players.black)
    end)
  end

  @doc """
  Returns a list of completed games
  """
  def list_completed_games do
    list_active_games()
    |> Enum.filter(fn game ->
      game.status in [:checkmate_white, :checkmate_black, :stalemate,
                     :draw_insufficient_material, :draw_fifty_move_rule]
    end)
  end

  @doc """
  Cleans up abandoned or old completed games
  """
  def cleanup_old_games do
    # Get games to clean up
    abandoned_timeout = Application.get_env(:chess_app, :abandoned_game_timeout, 6 * 60 * 60) # 6 hours default
    completed_timeout = Application.get_env(:chess_app, :completed_game_timeout, 24 * 60 * 60) # 24 hours default

    now = DateTime.utc_now()

    # Find games to clean up
    games_to_cleanup = list_active_games()
    |> Enum.filter(fn game ->
      cond do
        # Completed games after timeout
        game.status in [:checkmate_white, :checkmate_black, :stalemate,
                      :draw_insufficient_material, :draw_fifty_move_rule] ->
          DateTime.diff(now, game.last_activity) > completed_timeout

        # Abandoned games - waiting for players with no activity
        game.status == :waiting_for_players ->
          DateTime.diff(now, game.created_at) > abandoned_timeout

        # Games in progress with no recent activity
        true ->
          DateTime.diff(now, game.last_activity) > abandoned_timeout
      end
    end)

    # Terminate each game
    games_to_cleanup |> Enum.each(fn %{game_id: game_id} ->
      DynamicSupervisor.terminate_child(
        ChessApp.GameSupervisor,
        Process.whereis(via_tuple(game_id) |> elem(2))
      )
    end)

    {:ok, length(games_to_cleanup)}
  end

  # Helper functions

  defp player_info(nil), do: nil
  defp player_info({_session_id, nickname}), do: %{nickname: nickname}

  defp get_creation_time(pid) do
    case Process.info(pid, [:dictionary]) do
      [{:dictionary, dict}] ->
        case Keyword.get(dict, :"$initial_call") do
          {_mod, :init, _} ->
            # Get created time from process dictionary or default to now
            Keyword.get(dict, :created_at, DateTime.utc_now())
          _ -> DateTime.utc_now()
        end
      _ -> DateTime.utc_now()
    end
  end

  defp get_last_activity(game_state) do
    case game_state.move_history do
      [%{timestamp: timestamp} | _] -> timestamp
      _ -> DateTime.utc_now()
    end
  end

  defp via_tuple(game_id) do
    {:via, Registry, {ChessApp.GameRegistry, game_id}}
  end
end
