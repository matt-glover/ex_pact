defmodule ProviderCaseTest do
  use ExUnit.Case, async: true
  import ExPact.ProviderCase

  setup do
    bypass = Bypass.open(port: 1234)

    mock_webserver(bypass)
    {:ok, bypass: bypass}
  end

  honours_pact_with("Alice service", "Consumer", "./test/pacts/v1-example-pact.json")

  defp mock_webserver(bypass) do
    Bypass.stub bypass, "GET", "/provider.json", fn conn ->
      conn
      |> Plug.Conn.resp(200, ~s<{"errors": [{"code": 88, "message": "Rate limit exceeded"}],"test": "NO","date": "2013-08-16T15:31:20+10:00", "count": 1000}>)
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.put_resp_header("x-extraneous", "extra headers")
    end
  end
end
