defmodule EquirouteWeb.PageController do
  use EquirouteWeb, :controller
  alias Equiroute.Sncf
  alias Equiroute.Mapbox
  alias Equiroute.TimeFormat
  alias Equiroute.StringNormalize
  alias Equiroute.Geoapify

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def select_cities(conn, params) do
    sources_params = Enum.filter(params["sources"], &(&1 != ""))
    destinations_params = Enum.filter(params["destinations"], &(&1 != ""))

    sources = Enum.map(sources_params, &Sncf.find_place/1)
    destinations = Enum.map(destinations_params, &Sncf.find_place/1)

    # if we have perfect matches for all params, we skip the select cities page,
    # redirecting directly to the result page
    sources_first_match = Enum.map(sources, &Enum.at(&1, 0, %{name: ""}))
    destinations_first_match = Enum.map(destinations, &Enum.at(&1, 0, %{name: ""}))

    normalized_params =
      (sources_params ++ destinations_params)
      |> Enum.map(&StringNormalize.normalize/1)

    normalized_places =
      (sources_first_match ++ destinations_first_match)
      |> Enum.map(&StringNormalize.normalize(&1.name))

    if normalized_params == normalized_places do
      redirect(conn,
        to:
          EquirouteWeb.PageView.result_link(
            Enum.map(sources_first_match, & &1.sncf_id),
            Enum.map(destinations_first_match, & &1.sncf_id),
            params["random"] == "true"
          )
      )
    end

    {sources, sources_no_results} =
      sources_params
      |> Enum.zip(sources)
      |> Enum.split_with(&(elem(&1, 1) != []))

    {destinations, destinations_no_results} =
      destinations_params
      |> Enum.zip(destinations)
      |> Enum.split_with(&(elem(&1, 1) != []))

    render(conn, "select_cities.html",
      sources: sources,
      destinations: destinations,
      sources_no_results: Enum.map(sources_no_results, &find_closest/1),
      destinations_no_results: Enum.map(destinations_no_results, &find_closest/1),
      random: params["random"] == "true"
    )
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
        EquirouteWeb.PageView.result_link(params["sources"], random_ids ++ params["destinations"])

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
