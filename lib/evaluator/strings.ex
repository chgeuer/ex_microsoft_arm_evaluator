defmodule Microsoft.Azure.TemplateLanguageExpressions.Evaluator.Strings do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  alias Microsoft.Azure.TemplateLanguageExpressions.JSONParser

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-string

  #
  # base64
  #
  def base64([val]), do: val |> Base.encode64()

  #
  # base64ToJson
  #
  def base64ToJson([val]) do
    with {:ok, base64decoded} <- Base.decode64(val),
         {:ok, result} <- Jason.decode(base64decoded) do
      result
    else
      err -> err
    end
  end

  #
  # base64ToString
  #
  def base64ToString([val]), do: val |> Base.decode64!()

  #
  # dataUri
  #
  def dataUri([val]) when is_binary(val) do
    with {:ok, encoded} <- ExDataURI.encode(val, "text/plain", "utf8") do
      encoded
    else
      err -> err
    end
  end

  #
  # dataUriToString
  #
  def dataUriToString([val]) when is_binary(val) do
    with {:ok, _mime_type, decoded} <- ExDataURI.parse(val) do
      decoded
    else
      err -> err
    end
  end

  #
  # endsWith
  #
  def endsWith([stringToSearch, stringToFind]),
    do:
      String.ends_with?(
        stringToSearch |> String.downcase(),
        stringToFind |> String.downcase()
      )

  #
  # startsWith
  #
  def startsWith([stringToSearch, stringToFind]),
    do:
      String.starts_with?(
        stringToSearch |> String.downcase(),
        stringToFind |> String.downcase()
      )

  def format(_), do: {:error, :not_implemented}

  def guid(args) do
    with {:ok, s} <- Jason.encode(args) do
      UUID.uuid5(nil, s)
    else
      err -> err
    end
  end

  def indexOf([stringToSearch, stringToFind]) do
    case :binary.match(
           stringToSearch |> String.downcase(),
           stringToFind |> String.downcase()
         ) do
      {pos, _length} -> pos
      :nomatch -> -1
    end
  end

  #
  # lastIndexOf
  #
  def lastIndexOf([stringToSearch, stringToFind]) do
    case :binary.matches(
           stringToSearch |> String.downcase(),
           stringToFind |> String.downcase()
         )
         |> List.last() do
      {pos, _length} -> pos
      nil -> -1
    end
  end

  def newGuid([]), do: UUID.uuid4()

  def padLeft([valueToPad, totalLength]), do: padLeft([valueToPad, totalLength, " "])

  def padLeft([valueToPad, totalLength, paddingCharacter]),
    do: String.pad_leading(valueToPad, totalLength, paddingCharacter |> String.first())

  def replace([originalString, oldString, newString]),
    do: String.replace(originalString, oldString, newString, global: true)

  def split([inputString, delimiter]) when is_binary(delimiter),
    do: String.split(inputString, delimiter)

  def split([inputString, delimiters]) when is_list(delimiters),
    do: String.split(inputString, :binary.compile_pattern(delimiters))

  def uniqueString(strings) do
    hashed =
      strings
      |> Enum.map(&:crypto.hash(:sha512, &1))

    :crypto.hash(:sha512, hashed)
    |> Base.encode64()
    |> String.replace(["/", "=", "+"], "")
    |> String.slice(0, 13)
  end

  def uri([baseUri, relativeUri]), do: baseUri |> URI.merge(relativeUri) |> to_string()
  def uriComponent([stringToEncode]), do: stringToEncode |> URI.encode_www_form()
  def uriComponentToString([uriEncodedString]), do: uriEncodedString |> URI.decode_www_form()

  def utcNow([]), do: Timex.now() |> Timex.format!("{YYYY}{0M}{0D}T{0h24}{0m}{0s}Z")
  def utcNow(["d"]), do: Timex.now() |> Timex.format!("{0M}{0D}{YYYY}")

  # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-string#utcnow
  # https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html
  # Timex.now() |> Timex.format!("{YYYY}-{0M}-{0D}T{0h24}:{0m}:{0s}Z")

  def string([val]), do: val |> JSONParser.to_elixir() |> Jason.encode!()
  def substring([val, start, len]) when is_binary(val), do: val |> String.slice(start, len)

  def take([val, numberToTake]) when is_binary(val) and is_integer(numberToTake),
    do: val |> String.slice(0, numberToTake)

  def take([val, numberToTake]) when is_list(val) and is_integer(numberToTake),
    do: val |> Enum.take(numberToTake)

  def take(_), do: {:error, :need_string_or_array_and_integer}

  def skip([val, numberToSkip]) when is_binary(val) and is_integer(numberToSkip),
    do: val |> String.slice(numberToSkip..-1)

  def skip([val, numberToSkip]) when is_list(val) and is_integer(numberToSkip),
    do: val |> Enum.drop(numberToSkip)

  def skip(_), do: {:error, :need_string_or_array_and_integer}

  def toLower([val]) when is_binary(val), do: val |> String.downcase()
  def toUpper([val]) when is_binary(val), do: val |> String.upcase()
  def trim([val]) when is_binary(val), do: val |> String.trim()
end
