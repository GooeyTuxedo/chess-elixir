# lib/chess_app/games/game_server.ex
defmodule ChessApp.Games.GameServer do
  use GenServer
  alias ChessApp.Games.Board

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  def create_game do
    game_id = generate_game_id()

    DynamicSupervisor.start_child(
      ChessApp.GameSupervisor,
      {__MODULE__, [game_id: game_id]}
    )

    {:ok, game_id}
  end

  def join_game(game_id, player_session_id, player_nickname) do
    GenServer.call(via_tuple(game_id), {:join_game, player_session_id, player_nickname})
  end

  def make_move(game_id, player_session_id, from, to) do
    GenServer.call(via_tuple(game_id), {:make_move, player_session_id, from, to})
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)

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
  def handle_call({:join_game, player_session_id, player_nickname}, _from, state) do
    # Check if player is already in the game
    player_color = get_player_color(state, player_session_id)

    if player_color do
      # Player already joined, return their color
      {:reply, {:ok, player_color}, state}
    else
      # If game is full, return error
      if state.players.white && state.players.black do
        {:reply, {:error, :game_full}, state}
      else
        # Assign player to first available color
        color = if is_nil(state.players.white), do: :white, else: :black

        # Update players map
        players = Map.put(state.players, color, {player_session_id, player_nickname})

        # Check if game can now start
        status = if players.white && players.black, do: :in_progress, else: :waiting_for_players

        # Update state
        state = %{state | players: players, status: status}

        # Broadcast new player
        Phoenix.PubSub.broadcast(
          ChessApp.PubSub,
          "game:#{state.game_id}",
          {:player_joined, color, player_nickname}
        )

        {:reply, {:ok, color}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:make_move, _player_session_id, _from, _to}, _from, state) do
    # Move validation will go here
    {:reply, {:error, :not_implemented}, state}
  end

  # Helper functions

  defp via_tuple(game_id) do
    {:via, Registry, {ChessApp.GameRegistry, game_id}}
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp get_player_color(state, player_session_id) do
    cond do
      match?({^player_session_id, _}, state.players.white) -> :white
      match?({^player_session_id, _}, state.players.black) -> :black
      true -> nil
    end
  end
end
