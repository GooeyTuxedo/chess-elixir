defmodule ChessApp.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :white_player_session, :string
      add :black_player_session, :string
      add :status, :string
      add :winner, :string
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
