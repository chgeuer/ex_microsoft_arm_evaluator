defmodule Microsoft.Azure.TemplateLanguageExpressions.REST.RestClient do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.

  defp proxy_config do
    case System.get_env("http_proxy") do
      nil ->
        []

      "" ->
        []

      proxy_cfg ->
        [host, port] = String.split(proxy_cfg, ":")
        port = String.to_integer(port)
        [
          connect_options: [
            proxy: {String.to_charlist(host), port},
            timeout: 40_000
          ]
        ]
    end
  end

  def new(base_url) when is_binary(base_url) do
    Req.new([base_url: base_url] ++ proxy_config())
  end

  def new(base_url, headers) when is_binary(base_url) and is_map(headers) do
    header_list = Map.to_list(headers)
    Req.new([base_url: base_url, headers: header_list] ++ proxy_config())
  end
end
