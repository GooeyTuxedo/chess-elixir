defmodule ChessAppWeb.TimeHelpers do
  @moduledoc """
  Helper functions for formatting time.
  """

  @doc """
  Returns a human-readable relative time string.
  Example: "2 minutes ago", "just now", "3 hours ago"
  """
  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 10 ->
        "just now"
      diff_seconds < 60 ->
        "#{diff_seconds} seconds ago"
      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes} #{pluralize(minutes, "minute")} ago"
      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours} #{pluralize(hours, "hour")} ago"
      diff_seconds < 604800 ->
        days = div(diff_seconds, 86400)
        "#{days} #{pluralize(days, "day")} ago"
      true ->
        format_date(datetime)
    end
  end

  defp pluralize(1, singular), do: singular
  defp pluralize(_n, singular), do: "#{singular}s"

  defp format_date(datetime) do
    month = month_name(datetime.month)
    "#{month} #{datetime.day}, #{datetime.year}"
  end

  defp month_name(1), do: "Jan"
  defp month_name(2), do: "Feb"
  defp month_name(3), do: "Mar"
  defp month_name(4), do: "Apr"
  defp month_name(5), do: "May"
  defp month_name(6), do: "Jun"
  defp month_name(7), do: "Jul"
  defp month_name(8), do: "Aug"
  defp month_name(9), do: "Sep"
  defp month_name(10), do: "Oct"
  defp month_name(11), do: "Nov"
  defp month_name(12), do: "Dec"
end
