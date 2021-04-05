defmodule Equiroute.Mapbox do
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

    {:ok, %Finch.Response{body: body}} = Finch.build(:get, url) |> Finch.request(MyFinch)
    Jason.decode!(body)
  end
end
