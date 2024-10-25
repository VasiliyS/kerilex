defmodule Watcher.KeyStateCache do
  @moduledoc """
  defines methods to hold the calculated KeyStates
  during the OOBI process

  note: OOBI key event log can hold establishment events for delegated `aid`s
  """
  alias Watcher.KeyStateCache
  alias Watcher.KeyState

  @opaque t :: %__MODULE__{
            cache: %{optional(Kerilex.pre()) => KeyState.t()},
            recoveries: list({Kerilex.pre(), Kerilex.int_sn()})
          }
  @doc false
  defstruct cache: %{}, recoveries: []

  @doc """
  create an empty `KeySateCache`
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @spec new!(nonempty_improper_list({Kerilex.pre(), KeyState.t()}, any())) :: t()
  @doc """
  create a new `KeySateCache` and add supplied `KeyState`s to it.
  Enables incremental update of the KEL and key states.
  """
  def new!(key_states) when is_list(key_states) do
    key_states
    |> Enum.reduce(
      new(),
      fn
        {pref, %KeyState{} = ks}, ksc ->
          put_key_state(ksc, pref, ks)

        v, _ksc ->
          raise ArgumentError, "expected a list of pairs `{pref, KeyState}`, got: '#{inspect(v)}'"
      end
    )
  end

  @spec put_key_state(t(), Kerilex.pre(), KeyState.t()) :: t()
  @doc """
  add put `KeyState` into the cache for a prefix
  """
  def put_key_state(key_state_cache, pref, key_state)

  def put_key_state(%__MODULE__{cache: c} = ksc, pre, %KeyState{} = ks) do
    %__MODULE__{ksc | cache: Map.put(c, pre, ks)}
  end

  @spec get_key_state!(t(), Kerilex.pre()) :: KeyState.t()
  @doc """
  returns current `KeyState` for an AID, or raises an error if not found
  """
  def get_key_state!(key_state_cache, pref)

  def get_key_state!(%__MODULE__{cache: c}, pref) do
    case Map.fetch(c, pref) do
      {:ok, val} ->
        val

      :error ->
        raise "no intermediate key state found for AID pref='#{pref}'"
    end
  end

  @spec get_key_state(t(), Kerilex.pre()) :: KeyState.t() | nil
  @doc """
  returns current `KeyState` for a prefix, if any
  """
  def get_key_state(key_state_cache, pref)

  def get_key_state(%__MODULE__{cache: c}, pref) do
    Map.get(c, pref)
  end

  @spec get_config_for(Watcher.KeyStateCache.t(), Kerilex.pre()) ::
          :not_found | {:ok, Kerilex.aid_conf()}
  @doc """
  returns the value of the `c` filed of cached key state for the given AID if present
  """
  def get_config_for(key_state_cache, pref)

  def get_config_for(%__MODULE__{cache: c}, pref) do
    if cfg = get_in(c[pref].c), do: {:ok, cfg}, else: :not_found
  end

  @spec put_last_event_info(
          Watcher.KeyStateCache.t(),
          Kerilex.pre(),
          Kerilex.kel_ilk(),
          Kerilex.int_sn(),
          Kerilex.said()
        ) ::
          {:error, String.t()}
          | {:ok, KeyStateCache.t()}
  @doc """
  updates the last processed vent info in the state cache for a prefix, is present
  """
  def put_last_event_info(key_state_cache, pref, type, sn, said)

  def put_last_event_info(%__MODULE__{cache: c} = ksc, pref, type, sn, said) do
    case c[pref] do
      nil ->
        {:error, "key state for pre='#{pref}' is not in key state cache"}

      ks ->
        ks = %{ks | last_event: {type, sn, said}}
        {:ok, %__MODULE__{ksc | cache: %{c | pref => ks}}}
    end
  end

  @spec get_last_event_for(Watcher.KeyStateCache.t(), Kerilex.pre()) ::
          :not_found | {:ok, {Kerilex.kel_ilk(), Kerilex.int_sn(), Kerilex.said()} | nil}
  @doc """
  returns the value of the `last_event` field of a cached key state for the given AID if present
  """
  def get_last_event_for(key_state_cache, pref)

  def get_last_event_for(%__MODULE__{cache: c}, pref) do
    if le = get_in(c[pref].last_event), do: {:ok, le}, else: :not_found
  end

  @doc """
  returns the value for a given key of the cached `KeyState` for a given AID.

  raises a runtime error if AID's `KeyState` is not in the cache
  """
  @key_state_keys KeyState.new() |> Map.from_struct() |> Map.keys()

  def fetch_for!(ksc, pref, key) when key in @key_state_keys do
    case KeyStateCache.get_key_state(ksc, pref) do
      ks when ks != nil ->
        Map.fetch!(ks, key)

      _ ->
        raise "no intermediate key state found, pref ='#{pref}', wanted key='#{inspect(key)}'"
    end
  end

  @spec get_all_aids(t()) :: list(Kerilex.pre())
  @doc """
  returns a list of all AIDs in the `KeyStateCache`
  """
  def get_all_aids(ksc)

  def get_all_aids(%__MODULE__{cache: c}) do
    Map.keys(c)
  end

  @doc """
  add a pair of AID prefix and the event's `sn` to the list of successful superseding recovery events
  """
  @spec add_recovery_info(t(), Kerilex.pre(), Kerilex.int_sn()) :: t()
  def add_recovery_info(%__MODULE__{recoveries: r} = sc, pre, sn) do
    %__MODULE__{sc | recoveries: [{pre, sn} | r]}
  end

  @doc """
  check if any recovery events have been reported
  """
  @spec has_recoveries?(t()) :: boolean()
  def has_recoveries?(%__MODULE__{recoveries: r}) do
    r == []
  end

  @doc """
  get list of reported recovery events
  """
  @spec get_recoveries(t()) :: [] | list({Kerilex.pre(), Kerilex.int_sn()})
  def get_recoveries(%__MODULE__{recoveries: r}) do
    r
  end

  @doc """
   checks if there's a reported recovery for the specified AID prefix
  """
 @spec has_recovery_for?(t(), Kerilex.pre()) :: boolean()
  def has_recovery_for?(%__MODULE__{} = ksc, pre) do
    if get_recovery_info(ksc, pre) != nil, do: true, else: false
  end

  @doc """
  returns reported recovery info, if present
  """
  @spec get_recovery_info(t(), Kerilex.pre()) :: {Kerilex.pre(), Kerilex.int_sn()} | nil
  def get_recovery_info(%__MODULE__{recoveries: r}, pre) do
   List.keyfind(r, pre, 0)
  end
end
