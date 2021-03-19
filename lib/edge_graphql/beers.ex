defmodule EdgeGraphql.Beers do
  @moduledoc false
  alias EdgeGraphql.PunkApi, as: Api

  @doc """
  Returns a list of beers by name if any.
  """
  def search_beers(name) do
    Api.search_beers(name)
  end
end
