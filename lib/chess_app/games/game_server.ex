defmodule ChessApp.Games.GameServer do
  use GenServer
  alias ChessApp.Games.Board

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  # Server callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)

    # Start with empty player slots
    {:ok, %{
      game_id: game_id,
      board: Board.new(),
      players: %{
        white: nil, # Will store {session_id, nickname} tuples
        black: nil
      },
      status: :waiting_for_players,
      move_history: []
    }}
  end

  @impl true
  def handle_call({:join_game, player_session, player_nickname}, _from, state) do
    # If game is full, return error
    if state.players.white && state.players.black do
      {:reply, {:error, :game_full}, state}
    else
      # Assign player to first available color
      color = if is_nil(state.players.white), do: :white, else: :black

      # Update players map
      players = Map.put(state.players, color, {player_session, player_nickname})

      # Check if game can now start
      status = if players.white && players.black, do: :in_progress, else: :waiting_for_players

      # Update state
      state = %{state | players: players, status: status}

      # Broadcast new player
      Phoenix.PubSub.broadcast(ChessApp.PubSub, "game:#{state.game_id}",
        {:player_joined, color, player_nickname})

      {:reply, {:ok, color}, state}
    end
  end

  # ... other callbacks
end
