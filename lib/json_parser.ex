defmodule Microsoft.Azure.TemplateLanguageExpressions.JSONParser do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  import NimbleParsec

  defmodule JSONDocument do
    @derive {Inspect, only: [:value]}
    defstruct value: nil, space_before: nil, space_after: nil
    use Accessible
    # defimpl Inspect, for: __MODULE__ do
    #   def inspect(doc, _opts) do
    #     "JSONDocument \"#{doc |> JSONParser.encode()}\""
    #   end
    # end
  end

  defmodule JSONArray do
    @derive {Inspect, except: [:space]}
    defstruct value: nil, space: nil
    use Accessible
  end

  defmodule JSONObject do
    @derive {Inspect, only: [:value]}
    defstruct value: nil, space: nil
    use Accessible
  end

  defmodule JSONFloatObject do
    @derive {Inspect, only: [:value]}
    defstruct value: nil, string: nil
    use Accessible
  end

  defmodule JSONArrayElement do
    @derive {Inspect, only: [:value]}
    defstruct value: nil, space_before: nil, space_after: nil
    use Accessible
  end

  defmodule JSONObjectElement do
    @derive {Inspect, only: [:key, :value]}
    defstruct key: nil,
              value: nil,
              space_before_key: nil,
              space_after_key: nil,
              space_before_value: nil,
              space_after_value: nil

    use Accessible
    # defimpl Inspect, for: __MODULE__ do
    #   def inspect(e, _opts) do
    #     "\"#{e.key}\": #{inspect e.value}"
    #   end
    # end
  end

  t_sign =
    optional(
      choice([
        string("+"),
        string("-")
      ])
    )

  defp reduce_to_integer(acc),
    do:
      acc
      |> Enum.join()
      |> String.to_integer(10)

  t_integer =
    optional(t_sign)
    |> ascii_string([?0..?9], min: 1)
    |> lookahead_not(
      choice([
        string("e"),
        string("E"),
        string(".")
      ])
    )
    |> reduce(:reduce_to_integer)

  defp reduce_to_float(acc) do
    with float_as_string <- acc |> Enum.join(),
         {float_value, ""} <- float_as_string |> Float.parse() do
      %JSONFloatObject{value: float_value, string: float_as_string}
    end
  end

  t_number =
    optional(t_sign)
    |> ascii_string([?0..?9], min: 1)
    |> optional(
      string(".")
      |> ascii_string([?0..?9], min: 1)
    )
    |> optional(
      choice([
        string("e"),
        string("E")
      ])
      |> optional(t_sign)
      |> ascii_string([?0..?9], min: 1)
    )
    |> reduce(:reduce_to_float)

  t_boolean =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  t_null =
    string("null")
    |> replace(nil)

  # "   		\u0009 \u000d\u000a   " |> whitespace()
  t_whitespace =
    ascii_char([0x20, 0x0D, 0x0A, 0x09])
    |> times(min: 1)
    |> reduce({List, :to_string, []})

  # t_newline =
  #   ascii_char([0x0D, 0x0A]) |> times(min: 1)
  # t_online_comment =
  #   string("#")

  defp not_single_line_end(<<?\r, ?\n, _::binary>>, context, _, _), do: {:halt, context}
  defp not_single_line_end(<<?\r, _::binary>>, context, _, _), do: {:halt, context}
  defp not_single_line_end(<<?\n, _::binary>>, context, _, _), do: {:halt, context}
  defp not_single_line_end(_, context, _, _), do: {:cont, context}

  t_comment_single_line =
    string("//")
    |> repeat_while(
      utf8_char([]),
      {:not_single_line_end, []}
    )
    |> choice([
      string("\r\n"),
      string("\r"),
      string("\n")
    ])
    |> reduce({List, :to_string, []})

  defp not_multi_line_end(<<?*, ?/, _::binary>>, context, _, _), do: {:halt, context}
  defp not_multi_line_end(_, context, _, _), do: {:cont, context}

  t_comment_multi_line =
    string("/*")
    |> repeat_while(
      utf8_char([]),
      {:not_multi_line_end, []}
    )
    |> string("*/")
    |> reduce({List, :to_string, []})

  defp reduce_to_whitespace_or_comment([{:wsoc, []}]), do: {:wsoc, nil}
  defp reduce_to_whitespace_or_comment([{:wsoc, wsoc}]), do: {:wsoc, wsoc |> List.to_string()}
  defp reduce_to_whitespace_or_comment(wsoc) when is_binary(wsoc), do: {:wsoc, wsoc}

  t_whitespace_or_comment =
    repeat(
      choice([
        t_whitespace,
        t_comment_single_line,
        t_comment_multi_line
      ])
    )
    |> tag(:wsoc)
    |> reduce(:reduce_to_whitespace_or_comment)

  defp repeat_while_not_quote(<<?", _::binary>>, context, _, _), do: {:halt, context}
  defp repeat_while_not_quote(_, context, _, _), do: {:cont, context}

  # https://hexdocs.pm/nimble_parsec/NimbleParsec.html#utf8_string/3
  # regular:  '0020' . '10ffff' - '"' - '\'
  # escapes: \"  \\  \/  \b  \f  \n  \r  \t  \uFFFF
  t_string =
    ignore(string(~S/"/))
    |> repeat_while(
      choice([
        replace(string(~S/\"/), ~S/"/),
        utf8_char([])
      ]),
      {:repeat_while_not_quote, []}
    )
    |> ignore(string(~S/"/))
    |> reduce({List, :to_string, []})

  defp reduce_to_element(acc) do
    case acc do
      [value] ->
        %JSONArrayElement{value: value}

      [value, {:wsoc, wsoc2}] ->
        %JSONArrayElement{value: value, space_after: wsoc2}

      [{:wsoc, wsoc1}, value] ->
        %JSONArrayElement{value: value, space_before: wsoc1}

      [{:wsoc, wsoc1}, value, {:wsoc, wsoc2}] ->
        %JSONArrayElement{value: value, space_before: wsoc1, space_after: wsoc2}
    end
  end

  t_element =
    optional(t_whitespace_or_comment)
    |> concat(parsec(:t_value))
    |> optional(t_whitespace_or_comment)
    |> reduce(:reduce_to_element)

  defp reduce_to_array([{:array_empty, [{:wsoc, ws}]}]),
    do: %JSONArray{value: [], space: ws}

  defp reduce_to_array([{:array, array}]), do: %JSONArray{value: array}

  t_array =
    ignore(string("["))
    |> optional(t_element)
    |> repeat(
      ignore(string(","))
      |> concat(t_element)
    )
    |> ignore(string("]"))
    |> tag(:array)
    |> reduce(:reduce_to_array)

  t_array_empty =
    ignore(string("["))
    |> optional(t_whitespace_or_comment)
    |> ignore(string("]"))
    |> tag(:array_empty)
    |> reduce(:reduce_to_array)

  defp ws(nil), do: ""
  defp ws(whitespace) when is_binary(whitespace), do: whitespace

  defp reduce_to_member(acc) do
    case acc do
      [key, {:colon, ":"}, value] ->
        %JSONObjectElement{key: key, value: value}

      [key, {:colon, ":"}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{key: key, value: value, space_after_value: wsoc4}

      [key, {:colon, ":"}, {:wsoc, wsoc3}, value] ->
        %JSONObjectElement{key: key, value: value, space_before_value: wsoc3}

      [key, {:colon, ":"}, {:wsoc, wsoc3}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_value: wsoc3,
          space_after_value: wsoc4
        }

      [key, {:wsoc, wsoc2}, {:colon, ":"}, value] ->
        %JSONObjectElement{key: key, value: value, space_after_key: wsoc2}

      [key, {:wsoc, wsoc2}, {:colon, ":"}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_after_key: wsoc2,
          space_after_value: wsoc4
        }

      [key, {:wsoc, wsoc2}, {:colon, ":"}, {:wsoc, wsoc3}, value] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_after_key: wsoc2,
          space_before_value: wsoc3
        }

      [key, {:wsoc, wsoc2}, {:colon, ":"}, {:wsoc, wsoc3}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_after_key: wsoc2,
          space_before_value: wsoc3,
          space_after_value: wsoc4
        }

      [{:wsoc, wsoc1}, key, {:colon, ":"}, value] ->
        %JSONObjectElement{key: key, value: value, space_before_key: wsoc1}

      [{:wsoc, wsoc1}, key, {:colon, ":"}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_after_value: wsoc4
        }

      [{:wsoc, wsoc1}, key, {:colon, ":"}, {:wsoc, wsoc3}, value] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_before_value: wsoc3
        }

      [{:wsoc, wsoc1}, key, {:colon, ":"}, {:wsoc, wsoc3}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_before_value: wsoc3,
          space_after_value: wsoc4
        }

      [{:wsoc, wsoc1}, key, {:wsoc, wsoc2}, {:colon, ":"}, value] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_after_key: wsoc2
        }

      [{:wsoc, wsoc1}, key, {:wsoc, wsoc2}, {:colon, ":"}, value, {:wsoc, wsoc4}] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_after_key: wsoc2,
          space_after_value: wsoc4
        }

      [{:wsoc, wsoc1}, key, {:wsoc, wsoc2}, {:colon, ":"}, {:wsoc, wsoc3}, value] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_after_key: wsoc2,
          space_before_value: wsoc3
        }

      [
        {:wsoc, wsoc1},
        key,
        {:wsoc, wsoc2},
        {:colon, ":"},
        {:wsoc, wsoc3},
        value,
        {:wsoc, wsoc4}
      ] ->
        %JSONObjectElement{
          key: key,
          value: value,
          space_before_key: wsoc1,
          space_after_key: wsoc2,
          space_before_value: wsoc3,
          space_after_value: wsoc4
        }
    end
  end

  # whitespace #1
  t_member =
    optional(t_whitespace_or_comment)
    # key
    |> concat(t_string)
    # whitespace #2
    |> optional(t_whitespace_or_comment)
    # :
    |> concat(string(":") |> unwrap_and_tag(:colon))
    # whitespace #3
    |> optional(t_whitespace_or_comment)
    # value
    |> concat(parsec(:t_value))
    # whitespace #4
    |> optional(t_whitespace_or_comment)
    |> reduce(:reduce_to_member)

  defp reduce_to_object([{:object_empty, [{:wsoc, ws}]}]),
    do: %JSONObject{value: [], space: ws}

  defp reduce_to_object([{:object, array}]), do: %JSONObject{value: array}

  t_object =
    ignore(string("{"))
    |> optional(t_member)
    |> repeat(
      ignore(ascii_char([?,]))
      |> concat(t_member)
    )
    |> ignore(string("}"))
    |> tag(:object)
    |> reduce(:reduce_to_object)

  t_object_empty =
    ignore(string("{"))
    |> optional(t_whitespace_or_comment)
    |> ignore(string("}"))
    |> tag(:object_empty)
    |> reduce(:reduce_to_object)

  t_value =
    choice([
      t_null,
      t_string,
      t_boolean,
      t_integer,
      t_number,
      t_array,
      t_array_empty,
      t_object,
      t_object_empty
    ])

  defp reduce_surrounded_value(v) do
    case v do
      [{:json, [v]}] ->
        %JSONDocument{value: v}

      [{:json, [{:wsoc, ws1}, v]}] ->
        %JSONDocument{value: v, space_before: ws1}

      [{:json, [v, {:wsoc, ws2}]}] ->
        %JSONDocument{value: v, space_after: ws2}

      [{:json, [{:wsoc, ws1}, v, {:wsoc, ws2}]}] ->
        %JSONDocument{value: v, space_before: ws1, space_after: ws2}
    end
  end

  t_surrounded_value =
    optional(t_whitespace_or_comment)
    |> concat(t_value)
    |> optional(t_whitespace_or_comment)
    |> tag(:json)
    |> reduce(:reduce_surrounded_value)

  defparsecp(:t_value, t_value)

  defparsecp(:t_surrounded_value, t_surrounded_value)

  def parse(v) do
    case v |> t_surrounded_value() do
      {:ok, [result], "", _, _, _} -> result
      {:ok, _, unparsed, _, _, _} -> {:error, unparsed}
      {:error, _, unparsed, _, _, _} -> {:error, unparsed}
    end
  end

  defp map_join(values, mapper) when is_list(values) and is_function(mapper) do
    values
    |> Enum.map(mapper)
    |> Enum.join(",")
  end

  defp surrounded(v, :object), do: "{#{v}}"
  defp surrounded(v, :array), do: "[#{v}]"
  defp surrounded(v, s1, s2), do: "#{ws(s1)}#{v}#{ws(s2)}"

  defp poison_encode(value) do
    case value |> Jason.encode() do
      {:ok, v} -> v
      error -> error |> IO.inspect(label: :problem)
    end
  end

  def encode(v) do
    case v do
      %JSONDocument{value: value, space_before: wsoc1, space_after: wsoc2} ->
        value |> encode() |> surrounded(wsoc1, wsoc2)

      %JSONArray{value: [], space: ws} ->
        ws |> surrounded(:array)

      %JSONArray{value: values, space: nil} ->
        values |> map_join(&encode/1) |> surrounded(:array)

      %JSONArrayElement{value: element_value, space_before: wsoc1, space_after: wsoc2} ->
        element_value |> encode() |> surrounded(wsoc1, wsoc2)

      %JSONObject{value: [], space: ws} ->
        ws |> surrounded(:object)

      %JSONObject{value: values, space: nil} ->
        values |> map_join(&encode/1) |> surrounded(:object)

      %JSONObjectElement{
        key: key,
        value: value,
        space_before_key: wsoc1,
        space_after_key: wsoc2,
        space_before_value: wsoc3,
        space_after_value: wsoc4
      } ->
        "#{ws(wsoc1)}\"#{key}\"#{ws(wsoc2)}:#{ws(wsoc3)}#{value |> encode()}#{ws(wsoc4)}"

      %JSONFloatObject{value: _value, string: float_as_string} ->
        float_as_string

      value when is_list(value) ->
        value |> map_join(&encode/1) |> surrounded(:array)

      {:error, error_message} when is_binary(error_message) ->
        "\"Evaluation error: #{error_message}\""

      value ->
        value |> poison_encode()
    end
  end

  def to_elixir(v) do
    case v do
      %JSONDocument{value: value} -> value |> to_elixir()
      %JSONArray{value: values} -> values |> to_elixir()
      %JSONArrayElement{value: value} -> value |> to_elixir()
      %JSONObject{value: values} -> values |> Enum.map(&to_elixir/1) |> Enum.into(%{})
      %JSONObjectElement{key: key, value: value} -> {key, value |> to_elixir()}
      %JSONFloatObject{value: float_value} -> float_value
      array when is_list(array) -> array |> Enum.map(&to_elixir/1) |> Enum.into([])
      value -> value
    end
  end

  def get(x, path, alternative \\ nil)
  def get(nil, _, alternative), do: alternative
  def get(x, [], _), do: x

  def get(x, [name | tail], alternative) when x != nil,
    do:
      x
      |> get_in([:value, :value])
      |> Enum.find(&(&1 |> Map.get(:key) == name))
      |> get(tail, alternative)

  def fetch({:property, name}, value = %JSONObject{}) when is_binary(name),
    do:
      value
      |> Map.get(:value)
      |> Enum.find(&(&1 |> Map.get(:key) == name))
      |> Map.get(:value)

  def fetch({:property, name}, value)
      when is_binary(name) and is_map(value),
      do: value |> Map.fetch!(name)

  def fetch({:indexer, name}, array = %JSONArray{}) when is_binary(name),
    do:
      array
      |> Map.get(:value)
      |> Enum.find(&(&1 |> Map.get(:key) == name))
      |> Map.get(:value)

  def fetch({:indexer, name}, value = %{}) when is_binary(name),
    do: value |> Map.fetch!(name)

  def fetch({:indexer, index}, array = %JSONArray{}) when is_integer(index),
    do:
      array
      |> Map.get(:value)
      |> Enum.at(index)
      |> Map.get(:value)

  def fetch({:indexer, index}, value)
      when is_integer(index) and is_list(value),
      do: value |> Enum.at(index)
end
