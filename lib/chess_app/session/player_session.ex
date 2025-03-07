defmodule ChessApp.Session.PlayerSession do
  @moduledoc """
  Manages temporary player identities using session tokens.
  """

  @doc """
  Ensures the player has a session ID and nickname.
  """
  def ensure_player_session(conn) do
    session = Plug.Conn.get_session(conn)

    player_session_id = Map.get(session, "player_session_id")
    player_nickname = Map.get(session, "player_nickname")

    conn = if player_session_id do
      conn
    else
      # Generate a random session ID if none exists
      Plug.Conn.put_session(conn, "player_session_id", generate_session_id())
    end

    conn = if player_nickname do
      conn
    else
      # Generate a random nickname if none exists
      Plug.Conn.put_session(conn, "player_nickname", generate_nickname())
    end

    conn
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_nickname do
    adjectives = ["Swift", "Clever", "Bold", "Calm", "Eager", "Fierce", "Gentle", "Happy"]
    animals = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]

    "#{Enum.random(adjectives)}#{Enum.random(animals)}#{:rand.uniform(999)}"
  end
end
