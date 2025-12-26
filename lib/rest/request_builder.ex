defmodule Microsoft.Azure.TemplateLanguageExpressions.REST.RequestBuilder do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  alias Microsoft.Azure.TemplateLanguageExpressions.REST.{RestClient}

  def call(uri, method, %{aad_token_provider: aad_token_provider})
      when is_binary(uri)
      when method in [:get, :put] do
    # uri = "https://management.azure.com/subscriptions/?api-version=2019-06-01"
    connection = uri |> RestClient.new()

    token = uri |> trim_uri_for_aad_request() |> aad_token_provider.()

    opts =
      new_request()
      |> method(method)
      |> url(uri)
      # |> add_param(:query, :comp, "lease")
      # |> add_header("x-ms-lease-action", "acquire")
      |> add_header("Authorization", "Bearer #{token}")
      |> remove_empty_headers()
      |> add_missing(:query, [])
      |> Enum.into([])

    # |> IO.inspect(label: :RESTClientRequest)
    Req.request!(connection, opts)
    |> create_success_response()

    # |> IO.inspect(label: :RESTClientResponse)
  end

  def create_success_response(response) do
    Map.new()
    |> Map.put(:request_url, response.url)
    |> Map.put(:status, response.status)
    |> Map.put(:headers, response.headers)
    |> Map.put(:body, response.body)
    |> copy_response_headers_into_map()
    |> copy_x_ms_meta_headers_into_map()
    |> (fn response = %{body: body} ->
          case body |> Jason.decode() do
            {:ok, json} -> response |> Map.put(:body, json)
            _ -> response
          end
        end).()
  end

  def new_request(), do: %{}

  def method(request, m), do: request |> Map.put_new(:method, m)

  def url(request, u), do: request |> Map.put_new(:url, u)

  def body(request, body),
    do:
      request
      |> add_header("Content-Length", "#{body |> byte_size()}")
      |> Map.put(:body, body)

  def add_header_content_md5(request) do
    body = request |> Map.get(:body)
    md5 = :crypto.hash(:md5, body) |> Base.encode64()

    request
    |> add_header("Content-MD5", md5)
  end

  def add_header_if(request, false, _k, _v), do: request
  def add_header_if(request, true, k, v), do: request |> add_header(k, v)

  # request |> Map.update!(:headers, &Map.merge(&1, headers))
  def add_header(request = %{headers: headers}, k, v) when headers != nil,
    do: request |> Map.put(:headers, headers |> Map.put(k, v))

  def add_header(request, k, v), do: request |> Map.put(:headers, %{k => v})

  @prefix_x_ms_meta "x-ms-meta-"

  def add_header_x_ms_meta(request, kvp = %{}),
    do:
      kvp
      |> Enum.reduce(request, fn {k, v}, r -> r |> add_header(@prefix_x_ms_meta <> k, v) end)

  def add_optional_params(request, _, []), do: request

  def add_optional_params(request, definitions, [{key, value} | tail]) do
    case definitions do
      %{^key => location} ->
        request
        |> add_param(location, key, value)
        |> add_optional_params(definitions, tail)

      _ ->
        add_optional_params(request, definitions, tail)
    end
  end

  def add_param_if(request, false, _location, _key, _value), do: request

  def add_param_if(request, true, location, key, value),
    do: request |> add_param(location, key, value)

  def add_param(request, :body, :body, value), do: request |> Map.put(:body, value)

  def add_param(request, :body, key, value) do
    # Req handles JSON encoding automatically with the json option
    request
    |> Map.put(:json, %{key => value})
  end

  def add_param(request, :file, name, path) do
    # Req uses multipart forms differently
    request
    |> Map.put(:form, [{name, File.read!(path)}])
  end

  def add_param(request, :form, name, value) do
    request
    |> Map.update(:body, %{name => value}, &(&1 |> Map.put(name, value)))
  end

  def add_param(request, location, key, value) do
    request
    |> Map.update(location, [{key, value}], &(&1 ++ [{key, value}]))
  end

  def add_param(request, :query, opts) when is_list(opts) do
    filtered_opts = opts |> only_non_empty_values

    new_q =
      case request[:query] do
        nil -> filtered_opts
        query -> query ++ filtered_opts
      end

    request
    |> Map.put(:query, new_q)
  end

  defp only_non_empty_values(opts) when is_list(opts),
    do:
      opts
      |> Enum.filter(fn {_, value} -> value != nil && value != "" end)
      |> Enum.into([])

  def remove_empty_headers(request = %{headers: headers = %{}}) do
    new_headers =
      headers
      |> Enum.into([])
      |> Enum.filter(fn {_k, v} -> v != nil && String.length(v) > 0 end)
      |> Enum.into(%{})

    request
    |> Map.put(:headers, new_headers)
  end

  # defp get_header(headers, name) do
  #   headers
  #   |> Map.get(name)
  # end

  # defp protect(
  #        request = %{
  #          aad_token_provider: aad_token_provider,
  #          uri: uri
  #        }
  #      ) do
  #   token =
  #     uri
  #     |> trim_uri_for_aad_request()
  #     |> aad_token_provider.()
  #   request
  #   |> add_header("Authorization", "Bearer #{token}")
  # end

  def trim_uri_for_aad_request(uri) when is_binary(uri) do
    %URI{host: host, scheme: scheme} = uri |> URI.parse()

    %URI{host: host, scheme: scheme}
    |> URI.to_string()
  end

  def add_missing(map, key, value) do
    case map do
      %{^key => _} -> map
      %{} -> map |> Map.put(key, value)
    end
  end

  def decode(%{status: 200, body: body}), do: Jason.decode(body)
  def decode(response), do: {:error, response}
  def decode(%{status: 200} = env, false), do: {:ok, env}
  def decode(%{status: 200, body: body}, struct), do: Jason.decode(body, as: struct)
  def decode(response, _struct), do: {:error, response}

  def identity(x), do: x
  def to_bool("true"), do: true
  def to_bool("false"), do: false
  def to_bool(_), do: false

  def to_integer!(x) do
    {i, ""} = x |> Integer.parse()
    i
  end

  # def create_success_response(response, opts \\ []) do
  #   Map.new()
  #   |> Map.put(:request_url, response.url)
  #   |> Map.put(:status, response.status)
  #   |> Map.put(:headers, response.headers)
  #   |> Map.put(:body, response.body)
  #   |> copy_response_headers_into_map()
  #   |> copy_x_ms_meta_headers_into_map()
  # end

  @response_headers [
    # {"Date", :date, &DateTimeUtils.date_parse_rfc1123/1},
    # {"Last-Modified", :last_modified, &DateTimeUtils.date_parse_rfc1123/1},
    # {"Expires", :expires, &DateTimeUtils.date_parse_rfc1123/1},
    # {"ETag", :etag},
    # {"Content-MD5", :content_md5},
    {"x-ms-client-request-id", :x_ms_client_request_id},
    {"x-ms-request-id", :x_ms_request_id},
    {"x-ms-error-code", :x_ms_error_code},
    {"x-ms-cache-control", :x_ms_cache_control}
  ]

  defp copy_response_headers_into_map(response = %{}) do
    Enum.reduce(@response_headers, response, fn x, response ->
      response |> copy_response_header_into_map(x)
    end)
  end

  defp copy_response_header_into_map(response, {http_header, key_to_set}),
    do: response |> copy_response_header_into_map({http_header, key_to_set, &identity/1})

  defp copy_response_header_into_map(response, {http_header, key_to_set, transform})
       when is_map(response) and is_atom(key_to_set) and is_binary(http_header) and
              is_function(transform, 1) do
    http_header = http_header |> String.downcase()

    if response.headers |> Map.has_key?(http_header) do
      case response.headers[http_header] do
        nil -> response
        val -> response |> Map.put(key_to_set, val |> transform.())
      end
    else
      response
    end
  end

  defp copy_x_ms_meta_headers_into_map(response) do
    x_ms_meta =
      response.headers
      |> Enum.filter(fn {k, _v} -> k |> String.starts_with?(@prefix_x_ms_meta) end)
      |> Enum.map(fn {@prefix_x_ms_meta <> k, v} -> {k, v} end)
      |> Enum.into(%{})

    case x_ms_meta |> Enum.empty?() do
      true -> response
      false -> response |> Map.put(:x_ms_meta, x_ms_meta)
    end
  end
end
