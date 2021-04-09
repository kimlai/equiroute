defmodule EquirouteWeb.PageView do
  use EquirouteWeb, :view
  alias Plug.Conn.Query

  def result_link(sources, destinations, random \\ false) do
    extra_params =
      if random do
        [random: "true"]
      else
        []
      end

    "/result?#{Query.encode([sources: sources, destinations: destinations] ++ extra_params)}"
  end

  def google_map_url(%{coordinates: [lon1, lat1]}, %{coordinates: [lon2, lat2]}) do
    params = [origin: "#{lat1},#{lon1}", destination: "#{lat2},#{lon2}"]
    "https://www.google.com/maps/dir/?api=1&#{Query.encode(params)}"
  end

  def arrow(sources, source) do
    padding =
      sources
      |> Enum.map(&String.length(&1.name))
      |> Enum.max()

    "#{String.pad_leading("", padding - String.length(source.name), "-")}--->"
  end
end
