defmodule ExSyslogger.JsonFormatter do
  @moduledoc """
  JsonFormatter is formatter that produces a properly JSON object string where the level, message, node, and metadata are JSON object root properties.

  JSON object:
  ```
    {
      "level": "error",
      "message": "hello JSON formatter",
      "node": "foo@local",
      "module": "MyApp.MyModule",
      "function": "do_something/2",
      "line": 21
    }
  ```

  JSON string:
  ```
  {\"level\":\"error\",\"message\":\"hello JSON formatter\",\"node\":\"foo@local\",\"module\":\"MyApp.MyModule\",\"function\":\"do_something\/2\",\"line\":21}

  ```
  """

  @doc """
  Compiles a format string into an array that the `format/6` can handle.
  It uses Logger.Formatter.
  """
  @spec compile({atom, atom}) :: {atom, atom}
  @spec compile(binary | nil) :: [Logger.Formatter.pattern() | binary]

  defdelegate compile(str), to: Logger.Formatter

  @doc """
  Takes a compiled format and injects the level, message, node and metadata and returns a properly formatted JSON object where level, message, node and metadata properties are root JSON properties. Message is formated with Logger.Formatter.

  `config_metadata`: is the metadata that is set on the configuration e.g. `metadata: [:module, :line, :function]` to include `:module`, `:line` and `:function` keys. Can be set to `:all` to include all keys.
  """
  @spec format(
          {atom, atom} | [Logger.Formatter.pattern() | binary],
          Logger.level(),
          Logger.message(),
          Logger.Formatter.time(),
          Keyword.t(),
          list(atom)
        ) :: IO.chardata()

  def format(format, level, msg, timestamp, metadata, config_metadata) do
    case Code.ensure_loaded(Jason) do
      {:error, _} -> throw(:add_jason_to_your_deps)
      _ -> nil
    end

    metadata =
      case config_metadata do
        :all ->
          metadata

        keys when is_list(keys) ->
          metadata |> Keyword.take(keys)

        _ ->
          []
      end

    msg_str =
      format
      |> Logger.Formatter.format(level, msg, timestamp, metadata)
      |> to_string()

    log = %{level: level, message: msg_str, node: node()}
    metadata = Map.new(metadata, fn {key, value} -> {key, pre_encode(value)} end)

    {:ok, log_json} = apply(Jason, :encode, [Map.merge(metadata, log)])

    log_json
  end

  ##############################################################################
  #
  # Internal functions

  # traverse data and stringify special Elixir/Erlang terms
  defp pre_encode(it) when is_pid(it), do: inspect(it)
  defp pre_encode(it) when is_function(it), do: inspect(it)
  defp pre_encode(it) when is_reference(it), do: inspect(it)
  defp pre_encode(it) when is_list(it), do: Enum.map(it, &pre_encode/1)
  defp pre_encode(it) when is_tuple(it), do: pre_encode(Tuple.to_list(it))

  defp pre_encode(%module{} = it) do
    try do
      :ok = Protocol.assert_impl!(Jason.Encoder, module)
      it
    rescue
      ArgumentError -> pre_encode(Map.from_struct(it))
    end
  end

  defp pre_encode(it) when is_map(it),
    do: Enum.into(it, %{}, fn {k, v} -> {pre_encode(k), pre_encode(v)} end)

  defp pre_encode(it) when is_binary(it) do
    it
    |> String.valid?()
    |> case do
      true -> it
      false -> inspect(it)
    end
  end

  defp pre_encode(it), do: it
end
