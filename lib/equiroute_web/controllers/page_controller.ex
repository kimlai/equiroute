defmodule EquirouteWeb.PageController do
  use EquirouteWeb, :controller
  alias Equiroute.Sncf
  alias Equiroute.Mapbox
  alias Equiroute.TimeFormat
  alias Equiroute.StringNormalize
  alias Equiroute.Geoapify
  alias Plug.Conn.Query

  def index(conn, _params) do
    render(conn, "index.html", error: nil, sources: [], destinations: [])
  end

  def validate_cities(conn, params) do
    sources_params = Enum.filter(params["sources"], &(&1 != ""))
    destinations_params = Enum.filter(params["destinations"], &(&1 != ""))

    if(sources_params == [] or (destinations_params == [] and !params["random"])) do
      render(conn, "index.html",
        error: "Veuillez entrer au moins une ville de départ et une ville d'arrivée",
        sources: params["sources"],
        destinations: params["destinations"]
      )
    else
      redirect(conn,
        to:
          "/select-cities?#{Query.encode(Map.take(params, ["sources", "destinations", "random"]))}"
      )
    end
  end

  def select_cities(conn, params) do
    sources = find_cities(params["sources"])
    destinations = find_cities(params["destinations"])

    if sources.only_perfect_matches and destinations.only_perfect_matches do
      redirect(conn,
        to:
          EquirouteWeb.PageView.result_link(
            Enum.map(sources.matches, fn {_, [match | _]} -> match.sncf_id end),
            Enum.map(destinations.matches, fn {_, [match | _]} -> match.sncf_id end),
            params["random"] == "true"
          )
      )
    end

    render(conn, "select_cities.html",
      sources: sources.matches,
      destinations: destinations.matches,
      sources_no_results: sources.closest,
      destinations_no_results: destinations.closest,
      random: params["random"] == "true"
    )
  end

  defp find_cities(names) do
    names = Enum.filter(names, &(&1 != ""))
    results = Enum.map(names, &Sncf.find_place/1)

    normalized_names = Enum.map(names, &StringNormalize.normalize/1)

    normalized_first_matches =
      results
      |> Enum.map(&Enum.at(&1, 0, %{name: ""}))
      |> Enum.map(&StringNormalize.normalize(&1.name))

    {with_results, no_results} =
      Enum.zip(names, results)
      |> Enum.split_with(&(elem(&1, 1) != []))

    %{
      only_perfect_matches: normalized_names == normalized_first_matches,
      normalized_inputs: Enum.map(names, &StringNormalize.normalize/1),
      matches: with_results,
      closest: Enum.map(no_results, &find_closest/1)
    }
  end

  defp find_closest({name, _}) do
    case Geoapify.geocode(name) do
      {:ok, {geocoded_name, coordinates}} ->
        {geocoded_name, Sncf.find_closest(coordinates)}

      _ ->
        {name, []}
    end
  end

  def compute(conn, params) do
    if params["random"] == "true" do
      random_ids =
        10
        |> Sncf.random_administrative_regions()
        |> Enum.map(& &1["id"])

      url =
        EquirouteWeb.PageView.result_link(
          params["sources"],
          random_ids ++ (params["destinations"] || [])
        )

      redirect(conn, to: url)
    end

    sources = Enum.map(params["sources"], &Sncf.place/1)
    destinations = Enum.map(params["destinations"], &Sncf.place/1)

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
              source
              |> Map.put(:car, Enum.at(Enum.at(car_matrix["durations"], i), j))
              |> Map.put(:train, Enum.at(Enum.at(train_matrix, i), j))
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
