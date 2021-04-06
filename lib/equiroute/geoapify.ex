defmodule Equiroute.Geoapify do
  alias Equiroute.Http
  alias Plug.Conn.Query

  @base_url "https://api.geoapify.com/v1/"

  # https://api.geoapify.com/v1/geocode/search?text=38%20Upper%20Montagu%20Street%2C%20Westminster%20W1H%201LJ%2C%20United%20Kingdom&apiKey=
  def geocode(query) do
    token = System.get_env("GEOAPIFY_TOKEN")
    params = Query.encode(text: query, apiKey: token)
    url = "#{@base_url}/geocode/search?#{params}"

    case Http.get_json(url) do
      {:ok, %{"features" => [first_match | _]}} ->
        {:ok, {first_match["properties"]["formatted"], first_match["geometry"]["coordinates"]}}

      {:ok, _} ->
        {:error, :no_match}

      error ->
        error
    end
  end
end
