defmodule EquirouteWeb.PageView do
  use EquirouteWeb, :view
  alias Plug.Conn.Query

  def random_link(sources, random_ids) do
    "/result?#{Query.encode(sources: sources, destinations: random_ids)}"
  end
end
