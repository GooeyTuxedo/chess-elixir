defmodule ChessApp.Games.Move do
  use Ecto.Schema
  import Ecto.Changeset

  schema "moves" do
    field :timestamp, :utc_datetime
    field :player_session, :string
    field :piece, :string
    field :from_position, :string
    field :to_position, :string
    field :notation, :string
    field :game_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(move, attrs) do
    move
    |> cast(attrs, [:player_session, :piece, :from_position, :to_position, :notation, :timestamp])
    |> validate_required([
      :player_session,
      :piece,
      :from_position,
      :to_position,
      :notation,
      :timestamp
    ])
  end
end
