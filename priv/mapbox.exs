points = %{
  "marseille" => %{name: "Marseille", coordinates: [5.3102854, 43.2803691]},
  "lyon" => %{name: "Lyon", coordinates: [4.8000158, 45.7579501]},
  "paris" => %{name: "Paris", coordinates: [2.2069771, 48.8587741]},
  "nantes" => %{name: "Nantes", coordinates: [-1.6300958, 47.2382007]},
  "bourges" => %{name: "Bourges", coordinates: [2.3631983, 47.0780326]},
  "jura" => %{name: "Jura", coordinates: [5.1688343, 46.7819516]},
  "pau" => %{name: "Pau", coordinates: [-0.4136968, 43.3218841]},
  "clermont" => %{name: "Clermont-Ferrand", coordinates: [3.0426862, 45.7870431]},
  "macon" => %{name: "Mâcon", coordinates: [4.7732329, 46.3265386]}
}

defmodule Mapbox do
  # https://api.mapbox.com/directions-matrix/v1/mapbox/driving/5.3102854,43.2803691;5.5151889,43.2185116?access_token=pk.eyJ1Ijoia2ltbGFpIiwiYSI6ImNpdHg4b3psMDAwMnAzd29hZ2VrbzVmeTcifQ.JEzjYNojtEPRBove3beibA

  def matrix(sources, destinations) do
    token =
      "pk.eyJ1Ijoia2ltbGFpIiwiYSI6ImNpdHg4b3psMDAwMnAzd29hZ2VrbzVmeTcifQ.JEzjYNojtEPRBove3beibA"

    coordinates =
      (sources ++ destinations)
      |> Enum.map(& &1.coordinates)
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join(";")

    sources_indexes = 0..(length(sources) - 1) |> Enum.join(";")

    destinations_indexes =
      length(sources)..(length(sources) + length(destinations) - 1)
      |> Enum.join(";")

    url =
      "https://api.mapbox.com/directions-matrix/v1/mapbox/driving/#{coordinates}?access_token=#{
        token
      }&sources=#{sources_indexes}&destinations=#{destinations_indexes}"

    IO.puts("fetching the matrix from Mapbox")

    {:ok, %Finch.Response{body: body}} = Finch.build(:get, url) |> Finch.request(MyFinch)
    Jason.decode!(body)
  end
end

defmodule TimeFormat do
  def format(seconds) when is_float(seconds), do: format(round(seconds))

  def format(seconds) do
    hours = div(seconds, 3600)
    remainder = rem(seconds, 3600)
    minutes = div(remainder, 60)
    format(hours, minutes)
  end

  defp format(hours, minutes), do: "#{hours}h#{pad(minutes)}"

  defp pad(number), do: :io_lib.format('~2..0B', [number])
end

defmodule Stats do
  def variance(values) do
    squared = Enum.map(values, &(&1 * &1))
    avg(squared) - avg(values) * avg(values)
  end

  def avg(values), do: Enum.sum(values) / length(values)

  def standard_deviation(values), do: :math.sqrt(variance(values))

  def range(values), do: Enum.max(values) - Enum.min(values)
end

sources = [points["marseille"], points["lyon"], points["paris"], points["nantes"]]

destinations = [
  points["bourges"],
  points["jura"],
  points["pau"],
  points["clermont"],
  points["macon"],
  points["lyon"]
]

result = Mapbox.matrix(sources, destinations)

for {destination, j} <- Enum.with_index(destinations) do
  dest_durations = Enum.map(result["durations"], &Enum.at(&1, j))
  IO.puts("--------------------------------")
  IO.puts(destination.name)
  IO.puts("Temps total : #{Enum.sum(dest_durations) |> TimeFormat.format()}")
  IO.puts("Temps moyen : #{Stats.avg(dest_durations) |> TimeFormat.format()}")
  IO.puts("Max : #{Enum.max(dest_durations) |> TimeFormat.format()}")
  IO.puts("Étendue : #{Stats.range(dest_durations) |> TimeFormat.format()}")
  IO.puts("Écart-type : #{Stats.standard_deviation(dest_durations) |> TimeFormat.format()}")

  for {source, i} <- Enum.with_index(sources) do
    IO.puts(
      "de #{source.name} -> #{TimeFormat.format(Enum.at(Enum.at(result["durations"], i), j))}"
    )
  end
end

IO.puts("--------------------------------")
