defmodule EdgeGraphqlWeb.BeersResolver do
  @moduledoc false

  alias EdgeGraphql.Beers

  @type root :: map()
  @type args :: map()
  @type info :: map()

  @doc """
  Return a list of beers by name.
  If results were cached, will serve the cached answer. Otherwise, will fetch 
  from Punk and cache it for subsequent queries.
  """
  @spec search_beers(root(), args(), info()) :: {atom(), list()}
  def search_beers(_root, %{name: name}, _info) do
    case Cachex.get!(:graphql, "beer:#{name}") do
      nil ->
        beers = Beers.search_beers(name)
        Cachex.put(:graphql, "beer:#{name}", beers)
        {:ok, beers}
      beers ->
        {:ok, beers}
    end
  end
end
