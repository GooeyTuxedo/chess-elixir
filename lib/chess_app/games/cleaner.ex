defmodule ChessApp.Games.Cleaner do
  use GenServer
  alias ChessApp.Games.GameRegistry
  require Logger

  @default_interval 60 * 60 * 1000 # 1 hour in milliseconds

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server callbacks
  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)

    # Schedule the first cleanup
    schedule_cleanup(interval)

    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    case GameRegistry.cleanup_old_games() do
      {:ok, count} ->
        if count > 0 do
          Logger.info("Cleaned up #{count} abandoned or completed games")
        end
      error ->
        Logger.error("Error cleaning up games: #{inspect error}")
    end

    # Schedule the next cleanup
    schedule_cleanup(state.interval)

    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
