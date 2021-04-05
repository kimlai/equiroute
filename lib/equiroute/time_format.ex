defmodule Equiroute.TimeFormat do
  def format(seconds) when is_float(seconds), do: format(round(seconds))
  def format(nil), do: nil

  def format(seconds) do
    hours = div(seconds, 3600)
    remainder = rem(seconds, 3600)
    minutes = div(remainder, 60)
    format(hours, minutes)
  end

  defp format(hours, minutes), do: "#{hours}h#{pad(minutes)}"

  defp pad(number), do: :io_lib.format('~2..0B', [number])
end
