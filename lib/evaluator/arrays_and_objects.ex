defmodule Microsoft.Azure.TemplateLanguageExpressions.Evaluator.ArraysAndObjects do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-array

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-array#array
  def array([_ | [_]]), do: {:error, :requires_single_argument}
  def array([val]), do: [val]

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-array#coalesce
  def coalesce(args), do: args |> Enum.find(&(&1 != nil))

  #
  # concat
  #
  def concat(val = [head | _tail]) when is_binary(head), do: val |> IO.iodata_to_binary()
  def concat(val = [head | _tail]) when is_list(head), do: val |> Enum.concat()
  def concat(_), do: {:error, :need_string_or_array_or_object}

  #
  # contains
  #
  def contains([container, itemToFind]) when is_binary(container) and is_binary(itemToFind),
    do: container |> String.contains?(itemToFind)

  def contains([container, itemToFind])
      when is_list(container) and (is_binary(itemToFind) or is_integer(itemToFind)),
      do: container |> Enum.member?(itemToFind)

  def contains([container = %{}, itemToFind]) when is_binary(itemToFind),
    do:
      container
      |> Map.keys()
      |> Enum.map(&String.downcase/1)
      |> Enum.member?(itemToFind |> String.downcase())

  def contains(_), do: {:error, :unsupported_args}

  def createArray(vals), do: vals |> Enum.into([])

  #
  # empty
  #
  def empty([[]]), do: true
  def empty([""]), do: true
  def empty([val = %{}]) when map_size(val) == 0, do: true
  def empty([_]), do: false

  #
  # first
  #
  def first([[]]), do: {:error, :need_non_empty_list_or_string}
  def first([""]), do: {:error, :need_non_empty_list_or_string}
  def first([[hd | _tail]]), do: hd
  def first([string]) when is_binary(string), do: string |> String.first()
  def first(_), do: {:error, :need_string_or_array}

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-array#intersection
  def intersection([first_set | other_sets]) when is_list(first_set) or is_map(first_set) do
    #
    # Use first_set as accumulator in Enum.reduce/3
    #
    other_sets
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(MapSet.new(first_set), &MapSet.intersection/2)
    |> Enum.into(
      cond do
        is_list(first_set) -> []
        is_map(first_set) -> %{}
      end
    )
  end

  def intersection(_), do: {:error, :unsupported_args}

  def json([s]) when is_binary(s) do
    case s |> Jason.decode() do
      {:ok, result} -> result
      _ -> {:error, :json_parse_error}
    end
  end

  def json(_), do: {:error, :need_string}

  def last([[]]), do: {:error, :need_non_empty_list_or_string}
  def last([""]), do: {:error, :need_non_empty_list_or_string}
  def last([list]) when is_list(list), do: list |> List.last()
  def last([string]) when is_binary(string), do: string |> String.last()
  def last(_), do: {:error, :need_string_or_array}

  def length([val]) when is_binary(val), do: val |> String.length()
  def length([val]) when is_list(val), do: val |> Kernel.length()
  def length([val = %{}]), do: val |> Enum.count()
  def length([_]), do: {:error, :need_string_or_array_or_object}

  def range([startingInteger, numberofElements])
      when is_integer(startingInteger) and is_integer(numberofElements),
      do: startingInteger..(startingInteger + numberofElements - 1) |> Enum.to_list()

  def range(_), do: {:error, :need_two_integers}

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-array#union
  def union([first_map | other_maps]) when is_map(first_map) do
    other_maps
    |> Enum.reduce(first_map, fn map1, map2 ->
      Map.merge(map1, map2, fn _k, value1, _v2 -> value1 end)
    end)
  end

  def union([first_list | other_lists]) when is_list(first_list) do
    other_lists
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(first_list |> MapSet.new(), &MapSet.union/2)
    |> Enum.into([])
  end

  def union(_), do: {:error, :unsupported_args}
end
