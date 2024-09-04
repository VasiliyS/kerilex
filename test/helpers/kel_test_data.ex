defmodule KelTestData do
  @moduledoc """
  provides test KELs and their reference KeyStates

  file names in the `test/data` directory and their content should be in sync with the test data structures returned by the `TestKelData.Kels` module.
  """
  alias Watcher.KeyStateCache

  @type t() :: %KelTestData{parsed_kel: list(), state_cache: KeyStateCache.t()}
  defstruct parsed_kel: nil, state_cache: KeyStateCache

  @states Enum.reduce(KelTestData.Kels.__info__(:functions), %{}, fn {state_func, 0}, states ->
            {key, ks} = apply(KelTestData.Kels, state_func, [])
            Map.put(states, key, ks)
          end)

  defp data_set!(dataset_name) do
    Map.fetch!(@states, dataset_name)
  end


  @spec test_data!(String.t()) :: t()
  @doc """
  takes a filename in the `test/data` directory, which should be a file with a KERI KEL. E.g. response from an `oobi` endpoint.
  """
  def test_data!(file_name) do
    parsed_kel = parse_kel(file_name)
    state_cache = data_set!(file_name)
    %__MODULE__{parsed_kel: parsed_kel, state_cache: state_cache}
  end

  defp parse_kel(file_name) do
    cwd = File.cwd!()

    kel_file = Path.join(~w(#{cwd} test data #{file_name}))
    File.read!(kel_file) |> Kerilex.KELParser.parse()
  end
end
