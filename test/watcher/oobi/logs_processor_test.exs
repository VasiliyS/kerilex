defmodule Watcher.OOBI.LogsProcessorTest do
  @moduledoc """
  `Watcher.OOBI.LogsProcessor` tests
  """
  use ExUnit.Case, async: false
  alias Watcher.KeyState
  alias Watcher.KeyStateCache
  alias Watcher.OOBI.LogsProcessor
  alias Watcher.{EventEscrow, KeyStateStore}

  import LogProcessorTest.Helper

  # each test will have a fresh, separate copy of the `KeyStateStore` db
  @moduletag :tmp_dir

  setup ctx do
    init_db_for_test(ctx)
  end

  setup ctx do
    if test_kel_filename = ctx[:test_kel] do
      td = KelTestData.test_data!(test_kel_filename)
      Map.put(ctx, :kel_data, td)
    else
      :ok
    end
  end

  describe "basic oobi processing" do
    @tag test_kel: "delegator-plus-2-ixn.cesr"
    test "delegator with a delegate", ctx do
      {escrow, _state_cache} = do_log_processor_test(ctx)
      assert EventEscrow.empty?(escrow)
    end

    @tag test_kel: "delegator-plus-3-rot-changes.cesr"
    test "3 rot events with witness and key changes", ctx do
      {escrow, _state_cache} = do_log_processor_test(ctx)
      assert EventEscrow.empty?(escrow)
    end

    @tag test_kel: "delegator-abandoned.cesr"
    @tag pre: "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7"
    test "delegator rotated to nt=0 n=[]", ctx do
      {escrow, state_cache} = do_log_processor_test(ctx)
      assert EventEscrow.empty?(escrow)
      abandoned? = state_cache |> KeyStateCache.get_key_state!(ctx.pre) |> KeyState.abandoned?()
      assert abandoned?
    end
  end

  describe "out of order KEL processing" do
    @tag test_kel: "gleif-kel-july-23-24"
    test "events are processed correctly", %{
      kel_data: %KelTestData{parsed_kel: test_kel} = kel_data
    } do
      1..100
      |> Enum.each(fn _ ->
        :mnesia.clear_table(:kel)

        kel_data = %KelTestData{kel_data | parsed_kel: Enum.shuffle(test_kel)}
        {escrow, _test_state_cache} = do_log_processor_test(%{kel_data: kel_data})

        assert EventEscrow.empty?(escrow) == true
      end)
    end
  end

  describe "superseding recovery" do
    setup ctx do
      {setup_kel, recovery_kel} = ctx.recovery_kels
      setup_kel_data = KelTestData.test_data!(setup_kel)

      {escrow, setup_state_cache} =
        do_log_processor_test(%{kel_data: setup_kel_data})
      assert EventEscrow.empty?(escrow) == true

      kel_data = KelTestData.test_data!(recovery_kel)

      Map.merge(ctx, %{
        key_states: state_cache_to_key_states(setup_state_cache),
        kel_data: kel_data
      })
    end

    @tag recovery_kels:
           {"delegator-3-ixn-plus-rot-at-6.cesr", "delegator-superseding-recovery-rot-at-3.cesr"}
    test "recovery with at sn=3 not possible with existing rot at sn=6", %{
      kel_data: %KelTestData{parsed_kel: test_kel, state_cache: _ref_state_cache},
      key_states: states
    } do
      {:error, reason} =
        LogsProcessor.process_kel(test_kel, EventEscrow.new(), key_states: states)

      assert reason =~ ~r/type='rot' at sn='6'/
    end

    @tag recovery_kels:
           {"delegator-plus-2-ixn.cesr", "delegator-superseding-recovery-rot-at-3.cesr"}
    @tag pre: "EHpD0-CDWOdu5RJ8jHBSUkOqBZ3cXeDVHWNb_Ul89VI7"
    test "recovery succeeds and is done correctly", %{
      kel_data: %KelTestData{parsed_kel: test_kel, state_cache: ref_state_cache},
      key_states: states,
      pre: pre
    } do
      {:ok, escrow, state_cache} =
        LogsProcessor.process_kel(test_kel, EventEscrow.new(), key_states: states)

      assert EventEscrow.empty?(escrow)
      assert_state_cache_equal?(ref_state_cache, state_cache)

      refute KeyStateStore.has_event_after?(pre, 3, "*"),
             "all events after the recovered one must be deleted"
    end
  end

  defp do_log_processor_test(%{
         kel_data: %KelTestData{parsed_kel: test_kel, state_cache: ref_state_cache}
       }) do
    {:ok, escrow, test_state_cache} =
      test_kel |> LogsProcessor.process_kel(EventEscrow.new())

    assert assert_state_cache_equal?(test_state_cache, ref_state_cache)
    {escrow, test_state_cache}
  end
end
