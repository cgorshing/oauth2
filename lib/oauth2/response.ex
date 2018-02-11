defmodule OAuth2.Response do
  @moduledoc """
  Defines the `OAuth2.Response` struct which is created from the HTTP responses
  made by the `OAuth2.Client` module.

  ## Struct fields

  * `status_code` - HTTP response status code
  * `headers` - HTTP response headers
  * `body` - Parsed HTTP response body (based on "content-type" header)
  """

  require Logger
  import OAuth2.Util
  alias OAuth2.Serializer

  @type status_code :: integer
  @type headers     :: list
  @type body        :: binary | map

  @type t :: %__MODULE__{
    status_code: status_code,
    headers: headers,
    body: body
  }

  defstruct status_code: nil, headers: [], body: nil

  @doc false
  def new(code, headers, body) do
    headers = process_headers(headers)

    body = decode_response_body(body, content_encoding(headers))
    body = parse_response_body(body, content_type(headers))
    resp = %__MODULE__{status_code: code, headers: headers, body: body}

    if Application.get_env(:oauth2, :debug) do
      Logger.debug("OAuth2 Provider Response #{inspect resp}")
    end

    resp
  end

  defp process_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.downcase(k), v} end)
  end

  defp decode_response_body(body, nil), do: body
  defp decode_response_body(body, ""), do: body
  defp decode_response_body(body, "gzip"), do: :zlib.gunzip(body)
  defp decode_response_body(body, "x-gzip"), do: :zlib.gunzip(body)
  defp decode_response_body(body, encoding), do: body

  defp parse_response_body("", _type), do: ""
  defp parse_response_body(" ", _type), do: ""
  # Facebook sends text/plain tokens!?
  defp parse_response_body(body, "text/plain") do
    case URI.decode_query(body) do
      %{"access_token" => _} = token -> token
      _ -> body
    end
  end
  defp parse_response_body(body, "application/x-www-form-urlencoded"),
    do: URI.decode_query(body)
  defp parse_response_body(body, type), do: Serializer.decode!(body, type)
end
