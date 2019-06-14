defmodule ExPact.ProviderCase do
  @moduledoc """
  Generate test cases for a pact Provider.
  """

  defmacro honours_pact_with(provider_app, consumer_app, pact_uri) do
    parsed =
      File.read!(pact_uri)
      |> Jason.decode!()

    # TODO: This doesn't cope with omitted provider state
    test_blocks =
      Enum.reduce(parsed["interactions"], %{}, fn interaction, acc ->
        {_, updated} =
          Map.get_and_update(acc, interaction["providerState"], fn prior_test_list ->
            new_test_case = %{
              description: interaction["description"],
              request: interaction["request"],
              response: interaction["response"]
            }

            updated_test_list =
              case prior_test_list do
                test_cases when is_list(test_cases) -> [new_test_case | test_cases]
                _ -> [new_test_case]
              end

            {prior_test_list, updated_test_list}
          end)

        updated
      end)

    # TODO: Switch this all to a map of provider_state -> list of test blobs to generate appropriate describes per state
    # TODO: Until this fix it'll break when there are multiple cases with matching test text but different states
    Enum.map(test_blocks, fn {provider_state, test_cases} ->
      describe_text =
        "Verifying a pact between #{consumer_app} and #{provider_app}. Given #{provider_state}"

      quote do
        describe unquote(describe_text) do
          unquote(generate_tests(test_cases))
        end
      end
    end)
  end

  defp generate_tests(test_cases) do
    for %{description: description, request: pact_request, response: pact_response} <- test_cases do
      full_description = build_test_description(description, pact_request)

      quote do
        test unquote(full_description) do
          request = unquote(Macro.escape(pact_request))
          expected_response = unquote(Macro.escape(pact_response))

          IO.write("Request: ")
          IO.inspect(request)
          IO.write("Response: ")
          IO.inspect(expected_response)

          request_url = "http://localhost:1234#{unquote(build_url(pact_request))}"

          # TODO: Non-GET options. Ability to submit body
          actual_response =
            case String.upcase(request["method"]) do
              "GET" -> HTTPoison.get(request_url)
            end

          assert {:ok, http_response = %HTTPoison.Response{}} = actual_response

          assert expected_response["status"] == http_response.status_code

          expected_headers =
            Enum.map(expected_response["headers"], fn {key, value} ->
              {String.downcase(key), value}
            end)

          Enum.each(expected_headers, fn expected ->
            assert Enum.member?(http_response.headers, expected)
          end)

          expected_body =
            case expected_response["body"] do
              expected_content when is_binary(expected_content) ->
                assert expected_content == http_response.body

              expected_content when is_map(expected_content) ->
                assert {:ok, parsed_json} = Jason.decode(http_response.body)

                expected = MapSet.new(expected_content)
                actual = MapSet.new(parsed_json)
                assert MapSet.subset?(expected, actual)

              nil ->
                nil
            end
        end
      end
    end
  end

  defp build_test_description(base_description, pact_request) do
    full_url = build_url(pact_request)
    full_request = "#{String.upcase(pact_request["method"])} #{full_url}"
    "#{base_description} with #{full_request}"
  end

  defp build_url(pact_request) do
    query_component =
      case pact_request["query"] do
        query when is_binary(query) -> "?#{query}"
        nil -> ""
      end

    "#{pact_request["path"]}#{query_component}"
  end
end
