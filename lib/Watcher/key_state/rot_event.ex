defmodule Watcher.KeyState.RotEvent do
  @moduledoc """
  defines rotation (`rot`) event map for storing in the Key State Store

  functions can be used for 'drt' event as well.
  """
  @keys Kerilex.Event.rot_labels()

  import Kerilex.Constants
  import Comment

  const(keys, @keys)

  comment("""
  example of a `rot` event:

  {"v":"KERI10JSON00037f_",
  "t":"rot",
  "d":"ECphNWm1_jZOupeKh6C7TlBi81BlERqbnMpyqpnS4CJY",
  "i":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
  "s":"1",
  "p":"EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
  "kt":["1/3","1/3","1/3"],
  "k":[
      "DOXYF_BTBSk7_8dIOuFqsgqhNPJErgAv_HBCG76gP0c2",
      "DIgljngxRKPci2BUa00RBfLyDiroXXCli5DgRGSfizQ_",
      "DFK74xezKGTqgsuirR-7DaQsImL-92yHfXKRbgC8Yayr"
      ],
  "nt":["1/3","1/3","1/3","1/3","1/3","1/3","1/3"],
  "n":[
      "ECo0X7hXuLqjQ_4BGmqE7GlsE0ZJnzJv3p_3YH3hb4wM",
      "EHgOexUh8AvN7rXblsSr6MJE5Gn1HPq5Mv9KFpCpllKN",
      "ECH4pTtUI653ykKb_capPBkKF3RvBZRzyb5dPfuJCfOf",
      "ELXXiPwoaWOVOTLMOAmg4IKkjFHFs3q2hsL9tHvuuC2D",
      "EAcNrjXFeGay9qqMj96FIiDdXqdWjX17QXzdJvq58Zco",
      "ENdgU_S8bGoV2QcKIk6sz61ND8D6P5wKtfAQiUHvJTZa",
      "EEjaupNCfEvbdNaHTkzHc7MT3YTHFR0TZzEXeev2CsLA"
      ],
  "bt":"4",
  "br":[],
  "ba":[],
  "a":[
        {
          "i":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS",
          "s":"0",
          "d":"EINmHd5g7iV-UldkkkKyBIH052bIyxZNBn9pq-zNrYoS"
        }
      ]
  }
      -VDE
        -A AD <- 3 indexed controller sigs
          2A AB <- indexed controller sig #1 with "oind"
            AF <- "oind"=5
              C2S_PGpOQpbMNwQVOqP5jCUJ7EgFH2hr21V6uCbBAkK30idHj0K-ReRCe_o5iIP2bGhBK2MPeEt1P81ZLwk2YJ
          2A AC <- indexed controller sig #2 with "oind"
            AG <- "oind"=6
              DeP0o3Ns2ycFFonXIQwGClJimMZ6DHnGfUKJ3O9DzUV5AxVi3Q0oq03fpLyVWRXYCWa72i_o6ftwCVVNnYDN4L
          AA <- indexed controller sig # 0, no "oind"!
            AwpoZNY1cZl_0pxlWiHm2RPD1q2XFiFBAzUGOQWeLlBTWbfFtImbZo3cxVKCP2D5Rl49zlaLRekrONYvme2oAC
        -B AF <-  5 indexed witness sigs
        A
          AA TPoqGSBJ71O5k5S6S9dr0QDLQAsCneZV_9kZ80Gtnd0cZRVUpCKiYDxcqNcDvCn3Gp_sQxDIoIBReEc5j9MwB
        A
          BA z47o9pz5fufebnDBI74dqcFISCLkAzl-yk5jXO5Pb3O85Kc147_mLOt3BsCgvuNUOD1vy5xBZgaN_jJ1b6gYK
        A
          CD Y_3R39v9DJ2JsZmogg73Qt3x1u493Op5SxM-FYxMVGm6FPsRnkb6_oU34xbKnR7oM0w7HGRvIxIKRLNK6oyIB
        A
          DA ynWmM3cgGqRplmB0-RjbkfBr7wrXgyGDaOw5YXK3ln73pq8bdukB8eJBtgBqhepEKCqXoDyeGOqs-zjcyArsN
        A
          EC bhugduoDndA7WyMBLFEF9WKSBpgBx_c5GZQWPAFHZp9FUdVAqiUhg1HWDRcmO1JY_7QolDtrekE-KJM53vlEG
        -EAB0AAAAAAAAAAAAAAAAAAAAAAB1AAG2022-11-30T18c57c00d314532p00c00

  """)

  alias Watcher.KeyState.Establishment
  alias Kerilex.Attachment
  alias Attachment.{IndexedControllerSig}
  alias Watcher.KeyState
  alias Jason.OrderedObject, as: OO
  alias Watcher.KeyStateEvent, as: KSE
  alias Kerilex.Crypto.KeyTally

  @behaviour KSE
  @behaviour Establishment

  @impl KSE
  def new do
    Map.from_keys(@keys, nil)
  end

  @sigs_key Attachment.idx_ctrl_sigs()

  ################  conversion functionality, from parsed event (Jason.OrderedObject) to  simplified map ready for processing and storage

  @impl KSE
  def from_ordered_object(%OO{} = msg_obj, event_module \\ __MODULE__) do
    conversions = %{
      # "s" => &KSE.to_number/1,
      "bt" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1,
      "a" => &KSE.anchor_handler/1
    }

    KSE.to_storage_format(msg_obj, event_module, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to '#{msg_obj["t"]}' storage format"}

      rot ->
        validate_event(rot)
    end
  end

  defp validate_event(rot) do
    cond do
      rot["s"] == 0 ->
        {:error, "rot event must have sn > 0, got: #{rot["s"]}"}

      true ->
        KSE.validate_sig_ths_counts(rot)
    end
  end

  #######################  validation and conversion functionality to transform rot event to a new, valid key state

  @impl Establishment
  def to_state(rot_event, sig_auth, attachments, %KeyState{} = prev_state) do
    comment("""
    `rot` can do the following:
     1. use keys from the "n" list (either `icp` or updated through a prev `rot` )
     2. add and delete witnesses
     3. anchor a "seal", e.g. digest/said ("d") + sn ("s") + identifier ("i") of a `dip` or a tel event

     1 and 2 will be validated and calculated here

     3  is handled by the storage (as part of the OOBI/KEL stream processing),
     which will simply stores the event along with its `a` field.
    """)

    with :ok <- check_delegation(prev_state.di, rot_event["t"]),
         {:ok, sig_auth} <- validate_new_keys(prev_state, rot_event, sig_auth, attachments),
         {:ok, b} <-
           new_backers(prev_state.b, rot_event["ba"], rot_event["br"], rot_event["bt"]),
         {:ok, rot_auth} <- KeyTally.new(rot_event["nt"]) do
      {:ok,
       %KeyState{
         prev_state
         | k: rot_event["k"],
           kt: sig_auth,
           n: rot_event["n"],
           nt: rot_auth,
           b: b,
           bt: rot_event["bt"]
       }}
    else
      {:error, msg} ->
        {:error, "failed to create KeyState object from '#{rot_event["t"]}' event, " <> msg}
    end
  end

  @compile {:inline, check_delegation: 2}
  defp check_delegation(di, event_type) do
    case event_type do
      "rot" ->
        if di == false do
          :ok
        else
          {:error, "attempted to use 'rot' event on a delegated aid, di='#{di}'"}
        end

      "drt" ->
        if di == false do
          {:error, "attempted to use 'drt' event and 'di' in key state is false"}
        else
          :ok
        end
    end
  end

  def validate_new_keys(
        %KeyState{} = prev_state,
        %{} = rot_event,
        sig_auth,
        attachments
      )
      when is_map_key(attachments, @sigs_key) do
    comment("""
    see https://trustoverip.github.io/tswg-keri-specification/#reserve-rotation

    A Validator, therefore, MUST confirm that the set of keys in the current key list
    truly includes a satisfiable subset of the prior next key list and that the current
    key list is satisfiable with respect to both the current and prior next thresholds.
    *Actual satisfaction means that the set of attached signatures MUST satisfy both
    the current and prior next thresholds as applied to their respective key lists.*

    """)

    %{@sigs_key => idx_crtl_sigs} = attachments
    sig_keys = rot_event["k"]
    # {:ok, sig_auth} = KeyTally.new(rot_event["kt"])

    # {[cur_idx], [prior_next_idx]}, where prior_next_idx is nil for a new key
    # validate that sig_keys are either from the set of the prior next keys or new
    with {:ok, {cur_idxs, prior_next_idxs}} <-
           sig_idx_pairs(idx_crtl_sigs, sig_keys, prev_state.n),
         :ok <-
           check_auth_ths(prior_next_idxs, prev_state.nt, "rotation authority check failed: "),
         :ok <- check_auth_ths(cur_idxs, sig_auth, "signing authority check failed: ") do
      {:ok, sig_auth}
    end
  end

  def check_auth_ths(sig_idxs, auth, err_msg) do
    if KeyTally.satisfy?(auth, sig_idxs) do
      :ok
    else
      # TODO(VS) add KeyTally to kt/nt string diagnostics
      {:error, err_msg <> "signature indexes '#{inspect(sig_idxs)}"}
    end
  end

  def sig_idx_pairs(_idx_ctrl_sigs, _sig_keys, [] = _prior_next_keys) do
    {:error, "attempt to rotate abandoned AID, prior next keys n=[]"}
  end

  def sig_idx_pairs(idx_ctrl_sigs, sig_keys, prior_next_keys) do
    do_idx_pairs =
      fn %IndexedControllerSig{ind: ind, oind: oind}, {cidxs, pidxs} ->
        case do_check_key_rules(ind, oind, sig_keys, prior_next_keys) do
          {:error, _} = err ->
            {:halt, err}

          :new_key_added ->
            {:cont, {[ind | cidxs], pidxs}}

          :ok ->
            {:cont, {[ind | cidxs], [oind | pidxs]}}
        end
      end

    idx_ctrl_sigs
    |> Enum.reduce_while(
      {_curr_idxs = [], _prior_next_idxs = []},
      do_idx_pairs
    )
    |> case do
      {:error, _} = err -> err
      res -> {:ok, res}
    end
  end

  defp do_check_key_rules(ind, nil, sig_keys, _prior_next_keys) do
    # this is a bit excessive, but just to be on the safe side.
    if Enum.at(sig_keys, ind) != nil do
      :new_key_added
    else
      {:error, "out of bound signing key index(#{ind})"}
    end
  end

  defp do_check_key_rules(ind, oind, sig_keys, prior_next_keys) do
    # `rot` and `drt` simply add new keys via `2A` pointing to a key in the prev_next_key_array
    #  where has will not match!!
    #  :match <-
    #    (pnk == pnk_at_oidx && :match) ||
    #      {:error,
    #       "current signing key(#{key}) at ind(#{ind}) does not match next prior key(#{pnk_at_oidx}) at oind(#{oind})"} do
    with key <- Enum.at(sig_keys, ind),
         :key_found <-
           (key != nil && :key_found) || {:error, "out of bound signing key index(#{ind})"},
         pnk_at_oidx = Enum.at(prior_next_keys, oind),
         :key_found <-
           (pnk_at_oidx != nil && :key_found) ||
             {:error,
              "out of bound prior next key index='#{oind}' prior next keys n='#{inspect(prior_next_keys)}' )"},
         pnk = Kerilex.Crypto.hash_and_encode!(key) do
      if pnk != pnk_at_oidx, do: :new_key_added, else: :ok
    else
      {:error, _} = err -> err
    end
  end

  def new_backers(prev_backers, rot_ba, rot_br, rot_bt) do
    comment("""
      see:
      - https://trustoverip.github.io/tswg-keri-specification/#backer-remove-list
      - https://trustoverip.github.io/tswg-keri-specification/#backer-add-list

      the current backer list is updated by removing the AIDs in the Backer Remove, `br` list.
      The AIDs in the `br` list MUST be removed *before* any AIDs in the Backer Add,
      `ba` list are appended.

      the current backer list is updated by appending in *order* the AIDs from the Backer Add,
      `ba` list *except for any AIDs that already appear in the current Backer list*.
      The AIDs in the `ba` list MUST NOT be appended until all AIDs in the
      `br` list have been removed.
    """)

    upd_backers =
      if rot_br != [] do
        Enum.reject(prev_backers, &Enum.member?(rot_br, &1))
      else
        prev_backers
      end

    upd_backers = upd_backers ++ rot_ba

    if length(upd_backers) < rot_bt do
      {:error,
       "updated backers list (#{inspect(upd_backers)}) is smaller than new 'bt'(#{rot_bt})"}
    else
      {:ok, upd_backers}
    end
  end
end
