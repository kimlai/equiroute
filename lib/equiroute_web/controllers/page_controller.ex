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

    car_matrix = Mapbox.matrix(sources, destinations)

    train_matrix =
      for source <- sources, into: [] do
        for destination <- destinations, into: [] do
          Task.async(fn ->
            Sncf.journey_duration(source.sncf_id, destination.sncf_id)
          end)
        end
      end
      |> Enum.map(fn list -> Enum.map(list, &Task.await/1) end)

    result =
      for {destination, j} <- Enum.with_index(destinations), into: %{} do
        car_durations = Enum.map(car_matrix["durations"], &Enum.at(&1, j))
        train_durations = Enum.map(train_matrix, &Enum.at(&1, j))

        stats = %{
          total: Enum.sum(car_durations) |> TimeFormat.format(),
          avg: Stats.avg(car_durations) |> TimeFormat.format(),
          max_car: Enum.max(car_durations) |> TimeFormat.format(),
          max_train: Enum.max(train_durations) |> TimeFormat.format(),
          range: Stats.range(car_durations) |> TimeFormat.format(),
          std_deviation: Stats.standard_deviation(car_durations) |> TimeFormat.format(),
          sources:
            for {source, i} <- Enum.with_index(sources), into: [] do
              car =
                Enum.at(Enum.at(car_matrix["durations"], i), j)
                |> TimeFormat.format()

              train =
                Enum.at(Enum.at(train_matrix, i), j)
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
