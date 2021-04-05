defmodule Stats do
  def variance(values) do
    squared = Enum.map(values, &(&1 * &1))
    avg(squared) - avg(values) * avg(values)
  end

  def avg(values), do: Enum.sum(values) / length(values)

  def standard_deviation(values), do: :math.sqrt(variance(values))

  def range(values), do: Enum.max(values) - Enum.min(values)
end
