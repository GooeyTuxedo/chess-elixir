defmodule ChessApp.Repo.Migrations.CreateMoves do
  use Ecto.Migration

  def change do
    create table(:moves) do
      add :player_session, :string
      add :piece, :string
      add :from_position, :string
      add :to_position, :string
      add :notation, :string
      add :timestamp, :utc_datetime
      add :game_id, references(:games, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:moves, [:game_id])
  end
end
