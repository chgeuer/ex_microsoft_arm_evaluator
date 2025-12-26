defmodule Microsoft.Azure.TemplateLanguageExpressions.Evaluator.DummyData do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  @external_resource Path.join([__DIR__, "dummy_data.json"])

  with {:ok, body} <- File.read(Path.join([__DIR__, "dummy_data.json"])),
       {:ok, json} <- Jason.decode(body) do
    Enum.each(json, fn {provider, result} ->
      @provider provider
      @result result

      def dummy_data(@provider), do: @result
    end)
  end

  def dummy_data(provider), do: {:error, "Missing dummy data for #{provider}"}
end
