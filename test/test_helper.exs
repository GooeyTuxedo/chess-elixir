ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ChessApp.Repo, :manual)

# Start any applications needed for tests
Application.ensure_all_started(:chess_app)
