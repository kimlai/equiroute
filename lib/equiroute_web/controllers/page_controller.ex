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

    render(conn, "select_cities.html",
      sources: sources,
      destinations: destinations,
      random: params["random"] == "true"
    )
  end

  def compute(conn, params) do
    sources = Enum.map(params["sources"], &Sncf.place/1)

    random_sncf_ids =
      if params["random"] == "true" do
        10
        |> Sncf.random_administrative_regions()
        |> Enum.map(& &1["id"])
      else
        []
      end

    destinations =
      params
      |> Map.get("destinations", [])
      |> (&(&1 ++ random_sncf_ids)).()
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
          total: Enum.sum(car_durations),
          avg: Stats.avg(car_durations),
          max_car: Enum.max(car_durations),
          max_train: Enum.max(train_durations),
          range: Stats.range(car_durations),
          std_deviation: Stats.standard_deviation(car_durations),
          coordinates: destination.coordinates,
          sources:
            for {source, i} <- Enum.with_index(sources), into: [] do
              car = Enum.at(Enum.at(car_matrix["durations"], i), j)

              train = Enum.at(Enum.at(train_matrix, i), j)

              %{
                name: source.name,
                car: car,
                train: train
              }
            end
        }

        {destination.name, stats}
      end
      |> Enum.sort_by(fn {_, stats} -> Enum.min([stats.max_car, stats.max_train]) end)

    random_sncf_ids =
      10
      |> Sncf.random_administrative_regions()
      |> Enum.map(& &1["id"])

    render(conn, "result.html",
      result: result,
      sources: params["sources"],
      random_sncf_ids: random_sncf_ids
    )
  end
end
