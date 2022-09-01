defmodule ExSyslogger.JsonFormatterTest do
  use ExUnit.Case, async: true
  doctest ExSyslogger.JsonFormatter

  alias ExSyslogger.JsonFormatter

  @format JsonFormatter.compile("$message\n")

  describe "format/6" do
    test "with date in metadata" do
      assert JsonFormatter.format(
               @format,
               :error,
               "Hey",
               DateTime.utc_now(),
               [my_date: ~D[2022-07-07], my_time: ~U[2022-07-07 12:00:05Z], int: 4, float: 4.5],
               :all
             ) ==
               "{\"float\":4.5,\"int\":4,\"level\":\"error\",\"message\":\"Hey\\n\",\"my_date\":\"2022-07-07\",\"my_time\":\"2022-07-07T12:00:05Z\",\"node\":\"nonode@nohost\"}"
    end

    test "with nested metadata" do
      assert JsonFormatter.format(
               @format,
               :error,
               "Hey",
               DateTime.utc_now(),
               [my_map: %{a: ~D[2022-07-07], b: ~U[2022-07-07 12:00:05Z]}, list: [1, 2, 3]],
               :all
             ) ==
               "{\"level\":\"error\",\"list\":[1,2,3],\"message\":\"Hey\\n\",\"my_map\":{\"a\":\"2022-07-07\",\"b\":\"2022-07-07T12:00:05Z\"},\"node\":\"nonode@nohost\"}"
    end

    test "with reference in metadata" do
      ref = :erlang.make_ref()

      assert JsonFormatter.format(
               @format,
               :error,
               "Hey",
               DateTime.utc_now(),
               [my_reference: ref],
               :all
             ) ==
               "{\"level\":\"error\",\"message\":\"Hey\\n\",\"my_reference\":\"#{inspect(ref)}\",\"node\":\"nonode@nohost\"}"
    end

    test "with port in metadata" do
      port = Port.list() |> hd()

      assert JsonFormatter.format(
               @format,
               :error,
               "Hey",
               DateTime.utc_now(),
               [my_port: port],
               :all
             ) ==
               "{\"level\":\"error\",\"message\":\"Hey\\n\",\"my_port\":\"#{inspect(port)}\",\"node\":\"nonode@nohost\"}"
    end
  end
end
