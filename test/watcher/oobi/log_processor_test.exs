defmodule Watcher.OOBI.LogsProcessorTest do
  use ExUnit.Case
  alias ElixirLS.LanguageServer.Providers.Completion.Reducers.Struct
  alias Watcher.OOBI.LogsProcessor
  alias Watcher.EventEscrow

  setup do
    geda_kel_file = Path.join(~w(#{File.cwd!()} test data gleif-kel-july-23-24))
    gleif_geda_kel = File.read!(geda_kel_file) |> Kerilex.KELParser.parse()

    {:ok, %{test_kel: gleif_geda_kel}}
  end

  test "out of order events are processed correctly", %{test_kel: test_kel} do
    1..100
    |> Enum.each(fn _ ->
      :mnesia.clear_table(:kel)

      {:ok, escrow, _key_state_cache} =
        test_kel |> Enum.shuffle() |> LogsProcessor.process_kel(EventEscrow.new())

      assert EventEscrow.empty?(escrow) == true
    end)
  end
end
