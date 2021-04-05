defmodule EquirouteWeb.PageController do
  use EquirouteWeb, :controller
  alias Equiroute.Sncf
  alias Equiroute.Mapbox
  alias Equiroute.TimeFormat

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def select_cities(conn, params) do
    sources =
      params["sources"]
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&Sncf.find_place/1)

    destinations =
      params["destinations"]
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&Sncf.find_place/1)

    render(conn, "select_cities.html", sources: sources, destinations: destinations)
  end

  def compute(conn, params) do
    sources =
      params["sources"]
      |> Enum.map(&Sncf.place/1)

    destinations =
      params["destinations"]
      |> Enum.map(&Sncf.place/1)

    matrix = Mapbox.matrix(sources, destinations)

    result =
      for {destination, j} <- Enum.with_index(destinations), into: %{} do
        dest_durations = Enum.map(matrix["durations"], &Enum.at(&1, j))

        stats = %{
          total: Enum.sum(dest_durations) |> TimeFormat.format(),
          avg: Stats.avg(dest_durations) |> TimeFormat.format(),
          max: Enum.max(dest_durations) |> TimeFormat.format(),
          range: Stats.range(dest_durations) |> TimeFormat.format(),
          std_deviation: Stats.standard_deviation(dest_durations) |> TimeFormat.format(),
          sources:
            for {source, i} <- Enum.with_index(sources), into: [] do
              car =
                Enum.at(Enum.at(matrix["durations"], i), j)
                |> TimeFormat.format()

              train =
                Sncf.journey_duration(source.sncf_id, destination.sncf_id)
                |> TimeFormat.format()

              %{
                name: source.name,
                car: car,
                train: train
              }
            end
        }

        {destination.name, stats}
      end

    render(conn, "result.html", result: result)
  end
end
