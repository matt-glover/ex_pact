defmodule ProviderCaseV1Test do
  use ExUnit.Case, async: true
  import ExPact.ProviderCase

  setup do
    bypass = Bypass.open(port: 1234)

    mock_webserver(bypass)
    {:ok, bypass: bypass}
  end

  honours_pact_with("Alice service", "Consumer", "./test/pacts/v1-example-pact.json")

  defp mock_webserver(bypass) do
    Bypass.stub(bypass, "GET", "/mallory", fn conn ->
      %{"name" => "ron", "status" => "good"} = URI.decode_query(conn.query_string)

      conn
      |> Plug.Conn.resp(200, ~s("That is some good Mallory."))
      |> Plug.Conn.put_resp_content_type("text/html")
    end)
  end
end
