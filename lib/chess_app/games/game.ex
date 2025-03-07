defmodule ChessApp.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :status, :string
    field :started_at, :utc_datetime
    field :white_player_session, :string
    field :black_player_session, :string
    field :winner, :string
    field :ended_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:white_player_session, :black_player_session, :status, :winner, :started_at, :ended_at])
    |> validate_required([:white_player_session, :black_player_session, :status, :winner, :started_at, :ended_at])
  end
end
