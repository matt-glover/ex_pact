defmodule ExPact.ProviderCase do
  @moduledoc """
  Generate test cases for a pact Provider.
  """

  require ExUnit.Assertions

  defmacro __using__(opts) do
    quote do
      options = unquote(opts)
      port = Keyword.get(options, :port, 1234)
      @ex_pact_port port

      import ExPact.ProviderCase
    end
  end

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

          request_url = "http://localhost:#{@ex_pact_port}#{unquote(build_url(pact_request))}"

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
            case expected do
              {"content-type", header_data} ->
                match_content_type(header_data, http_response.headers)

              _ ->
                assert Enum.member?(http_response.headers, expected)
            end
          end)

          expected_body =
            case expected_response["body"] do
              expected_content when is_binary(expected_content) ->
                assert expected_content == http_response.body

              expected_content when is_map(expected_content) ->
                assert {:ok, parsed_json} = Jason.decode(http_response.body)

                # TODO: Deal with deep nesting of maps and lists
                expected = MapSet.new(expected_content)
                actual = MapSet.new(parsed_json)
                assert MapSet.subset?(expected, actual)

              expected_content when is_list(expected_content) ->
                assert {:ok, parsed_json} = Jason.decode(http_response.body)

                # TODO: Deal with deep nesting of maps and lists
                # TODO: Also deal with matcher rules overriding exact body match
                expected_content
                |> Enum.with_index()
                |> Enum.each(fn {expected, index} ->
                  assert expected == Enum.at(parsed_json, index)
                end)

              nil ->
                nil
            end
        end
      end
    end
  end

  def match_content_type(expected_content_type, actual_headers) do
    {base_expected_type, expected_parameters} = normalize_content_type(expected_content_type)

    # TODO: Clean this up and put targeted testing around it.
    matches =
      actual_headers
      |> Enum.filter(fn {key, _value} -> key == "content-type" end)
      |> Enum.map(fn {_key, value} -> normalize_content_type(value) end)
      |> Enum.filter(fn {base_actual_type, _} -> base_expected_type == base_actual_type end)
      |> Enum.any?(fn {_, actual_params} ->
        Enum.all?(expected_parameters, fn expected -> Enum.member?(actual_params, expected) end)
      end)

    ExUnit.Assertions.assert(
      matches,
      ~s(Expected #{inspect(actual_headers)} to include {"content-type", "#{expected_content_type}"})
    )
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

  defp normalize_content_type(value) do
    {[base_type], parameters} =
      value
      |> String.split(";", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.split(1)

    {base_type, parameters}
  end
end
