defmodule ChessApp.Repo do
  use Ecto.Repo,
    otp_app: :chess_app,
    adapter: Ecto.Adapters.Postgres
end
