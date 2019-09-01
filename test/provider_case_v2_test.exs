defmodule ProviderCaseV2Test do
  use ExUnit.Case, async: true
  use ExPact.ProviderCase, port: 1235

  setup do
    # TODO: Do something like this https://github.com/elixir-lang/elixir/blob/master/lib/ex_unit/lib/ex_unit/case.ex#L216-L223
    # TODO: with @ex_pact_port as a `port: ` option to use during URL construction and then retest after switching these all to
    # TODO: `use ExPact.ProviderCase` instead of `import ExPact.ProviderCase`
    # TODO: Note that this will `require` not `import` so might swap `honours_pact_with` for ExPact.honours_pact_with or
    # TODO: maybe explicitly import instead
    bypass = Bypass.open(port: 1235)

    mock_webserver(bypass)
    {:ok, bypass: bypass}
  end

  honours_pact_with("266_provider", "test_consumer", "./test/pacts/v2-example-pact.json")

  defp mock_webserver(bypass) do
    Bypass.stub(bypass, "GET", "/idm/user", fn conn ->
      conn
      |> Plug.Conn.resp(200, ~s("That is some good Mallory."))
      |> Plug.Conn.put_resp_content_type("application/json")
    end)
  end
end
