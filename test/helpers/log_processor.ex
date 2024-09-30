defmodule LogProcessorTest.Helper do
  @moduledoc """
    Helper function sof the `LogProcessorTest` module
  """
  alias Watcher.KeyStateCache
  alias Watcher.{KeyState, KeyStateStore}

  import ExUnit.Assertions, only: [assert: 2]

  @escape Enum.map(~c" [~#%&*{}\\:<>?/+|\"]", &<<&1::utf8>>)

  defp escape_path(path) do
    String.replace(path, @escape, "-")
  end

  def mk_tmp_dir!(module, dir_name) do
    module_path = inspect(module) |> escape_path()
    path = ~w|tmp test_runs #{module_path} #{dir_name}| |> Path.join() |> Path.expand()
    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end

  def assert_state_cache_equal?(left, right, msg \\ "") do
    aids1 = KeyStateCache.get_all_aids(left)
    aids2 = KeyStateCache.get_all_aids(right)
    aids1_set = :ordsets.from_list(aids1)
    aids2_set = :ordsets.from_list(aids2)

    assert :ordsets.is_equal(aids1_set, aids2_set), msg <> " lists of aids differ"

    Enum.each(aids1, fn pre ->
      ks1 = KeyStateCache.get_key_state!(left, pre)
      ks2 = KeyStateCache.get_key_state!(right, pre)

      assert key_state_equal?(ks1, ks2), msg <> " keys states for pre='#{pre}' differ"
    end)
  end

  def key_state_equal?(%KeyState{} = left, %KeyState{} = right) do
    ks1_sans_fs = %KeyState{left | fs: nil}
    ks2_sans_fs = %KeyState{right | fs: nil}

    ks1_sans_fs == ks2_sans_fs
  end

  def state_cache_to_key_states(state_cache) do
    for aid <- KeyStateCache.get_all_aids(state_cache), into: [] do
      {aid, KeyStateCache.get_key_state!(state_cache, aid)}
    end
  end

  def init_db_global(_ctx) do
    tmp_dir = mk_tmp_dir!(__MODULE__, "db")
    init_db_for_test(%{tmp_dir: tmp_dir})
  end

  def init_db_for_test(%{tmp_dir: tmp_dir}) do
    :stopped = :mnesia.stop()
    Application.put_env(:mnesia, :dir, tmp_dir |> String.to_charlist())
    :ok = Watcher.MnesiaHelpers.create_schema()
    :ok = KeyStateStore.init_tables()
  end
end
