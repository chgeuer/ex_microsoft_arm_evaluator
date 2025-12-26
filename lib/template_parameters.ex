defmodule Microsoft.Azure.TemplateLanguageExpressions.TemplateParameters do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  alias Microsoft.Azure.TemplateLanguageExpressions.{Context, JSONParser, JSONParser.JSONDocument}

  def parse_parameters_file_content(s) when is_binary(s) do
    s
    |> Jason.decode!()
    |> get_in(["parameters"])
    |> Enum.map(fn {k, %{"value" => v}} -> {k, v} end)
    |> Enum.into(%{})
  end

  def evaluate_effective_parameters(
        context = %Context{json: json, user_supplied_parameters: user_supplied_parameters}
      ) do
    effective_parameters =
      json
      |> parameters_from_json()
      |> combine_with(user_supplied_parameters)

    context
    |> Map.put(:effective_parameters, effective_parameters)
  end

  defp get_in_with_default(data, keys, default) do
    case data |> Kernel.get_in(keys) do
      nil -> default
      result -> result
    end
  end

  defp parameters_from_json(json = %JSONDocument{}),
    do:
      json
      |> JSONParser.get(["parameters"], %{})
      |> get_in_with_default([:value, :value], %{})
      |> Enum.map(fn json_element ->
        defaultValue =
          case json_element |> JSONParser.get(["defaultValue"]) do
            nil -> nil
            x -> x |> Map.fetch!(:value)
          end

        type = json_element |> JSONParser.get(["type"]) |> Map.fetch!(:value)

        {json_element.key, %{defaultValue: defaultValue, type: type}}
      end)
      |> Enum.into(%{})

  defp combine_with(doc_parameters, user_supplied_parameters) do
    # Suppress user-supplied parameters which are not in the document
    user_supplied_parameters =
      user_supplied_parameters
      |> Enum.filter(fn {k, _} -> doc_parameters |> Map.has_key?(k) end)
      |> Enum.into(%{})

    doc_parameters
    |> Map.merge(user_supplied_parameters, fn _k, doc, user ->
      # If the user didn't supply anything, try the defaultValue
      case user do
        nil -> doc |> Map.get(:defaultValue, nil)
        _ -> user
      end
    end)
    |> Enum.map(
      # The previous Map.merge doesn't 'see' values where the user didn't supply a value
      fn {k, v} ->
        case v do
          %{defaultValue: nil} -> {k, "ERROR: Missing parameter \"#{k}\""}
          %{defaultValue: defaultValue} -> {k, defaultValue}
          _ -> {k, v}
        end
      end
    )
    |> Enum.into(%{})
  end
end
