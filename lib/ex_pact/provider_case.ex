defmodule ExPact.ProviderCase do
  @moduledoc """
  Generate test cases for a pact Provider.
  """

  defmacro honours_pact_with(provider_app, consumer_app, pact_uri) do
    parsed =
      File.read!(pact_uri)
      |> Jason.decode!()

    # TODO: Jason.decode! into an object model?
    states =
      parsed["interactions"]
      |> Enum.map(fn interaction ->
        interaction["provider_state"]
      end)
      |> Enum.uniq()
    # TODO: Convert states into setup blocks grouped under the consumer app

    test_cases =
      parsed["interactions"]
      |> Enum.map(fn interaction ->
        %{
          description: interaction["description"],
          request: interaction["request"],
          response: interaction["response"]
        }
      end)

      # TODO: Switch this all to a map of provider_state -> list of test blobs to generate appropriate describes per state
    quote do
      describe "Verifying a pact between #{unquote(consumer_app)} and #{unquote(provider_app)}" do
        unquote(generate_tests(test_cases))
      end
    end
  end

  defp generate_tests(test_cases) do
    for %{description: description, request: pact_request, response: pact_response} <- test_cases do
      quote do
        test unquote(description) do
          request = unquote(Macro.escape(pact_request))
          expected_response = unquote(Macro.escape(pact_response))

          IO.write("Request: ")
          IO.inspect(request)
          IO.write("Response: ")
          IO.inspect(expected_response)

          # TODO: Proper construction and conditionals around all the optional bits
          request_url = "http://localhost:1234#{request["path"]}?#{request["query"]}"

          # TODO: Non-GET options. Ability to submit body
          actual_response =
            case request["method"] do
              "get" -> HTTPoison.get(request_url)
            end

          # TODO: check against all the possible response bits
          # defstruct status_code: nil, body: nil, headers: [], request_url: nil

          # TODO: Note: Need to consider swapping in String.to_existing_atom(string) or find a different way to handle this
          # TODO: That still allows consumers to provide more or less arbitrary headers
          expected_headers =
            Enum.map(expected_response["headers"], fn {key, value} ->
              {String.to_existing_atom(key), value}
            end)

          expected_body =
            case expected_response["body"] do
              content when is_binary(content) -> content
              content when is_map(content) -> content
              nil -> nil
            end

          assert {:ok,
                  %HTTPoison.Response{
                    status_code: expected_response["status"],
                    headers: expected_headers,
                    body: expected_body
                  }} ==
                   actual_response
        end
      end
    end
  end
end
