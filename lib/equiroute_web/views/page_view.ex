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

  def render("scripts.result.html", _) do
    ~E"<script defer src='https://api.mapbox.com/mapbox-gl-js/v2.2.0/mapbox-gl.js'></script>"
  end

  def render("css.result.html", _) do
    ~E"<link href='https://api.mapbox.com/mapbox-gl-js/v2.2.0/mapbox-gl.css' rel='stylesheet' />"
  end
end
