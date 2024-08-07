defmodule Watcher.KeyState.RotEvent do
  @moduledoc """
  defines rotation (`rot`) event map for storing in the Key State Store
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

  def new do
    Map.from_keys(@keys, nil)
  end

  alias Kerilex.Attachment
  alias Attachment.{IndexedControllerSig}
  alias Watcher.KeyState
  alias Kerilex.Crypto.KeyTally

  @sigs_key Attachment.idx_ctrl_sigs()

  alias Jason.OrderedObject, as: OO
  alias Watcher.KeyStateEvent, as: KSE
  alias Watcher.KeyState.Seal

  defp anchor_handler(anchors) do
    Enum.reduce_while(anchors,
    [],
    fn anchor, acc ->
      case KSE.to_storage_format(anchor, Seal, %{"s" => &KSE.to_number/1}) do
        :error ->
          {:halt, :error}
        seal ->
          {:cont, {:ok, [seal | acc]}}
      end
    end)
  end

  def from_ordered_object(%OO{} = msg_obj) do
    conversions = %{
      "s" => &KSE.to_number/1,
      "bt" => &KSE.to_number/1,
      "v" => &KSE.keri_version/1,
      "a" => &anchor_handler/1
    }

    KSE.to_storage_format(msg_obj, Watcher.KeyState.RotEvent, conversions)
    |> case do
      :error ->
        {:error, "failed to convert ordered object to 'rot' storage format"}

      rot ->
        validate_event(rot)
    end
  end

  defp validate_event(rot) do
    cond do
      rot["s"] == 0 ->
        {:error, "rot event must have sn > 0, got: #{rot["s"]}"}

      true ->
        {:ok, rot}

    end
  end

  def validate_new_keys(
        %KeyState{} = prev_state,
        %{} = rot_event,
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

    # {[cur_idx], [prior_next_idx]}, where prio_next_idx is nil for a new key
    # validate that sig_keys are either from the set of the prio next keys or new
    {:ok, {cur_idxs, prior_next_idxs}} = sig_idx_pairs(sig_keys, idx_crtl_sigs, prev_state.n)

    :ok = check_auth_ths(prior_next_idxs, prev_state.nt, "rotation autjority check failed: ")
    :ok = check_auth_ths(cur_idxs, rot_event["kt"], "signing authority check failed: ")
    :ok
  end

  def check_auth_ths(sig_idxs, ths, err_msg) do
    with {:ok, auth} <- KeyTally.new(ths),
         true <- KeyTally.satisfy?(auth, sig_idxs) do
      :ok
    else
      {:error, msg } ->
        {:error, err_msg <> msg}
      false ->
        {:error, err_msg <> "signature indexes '#{inspect(sig_idxs)}, thresholds '#{ths}'"}
    end
  end


  def sig_idx_pairs(sig_keys, idx_ctrl_sigs, prio_next_keys)
      when length(sig_keys) == length(idx_ctrl_sigs) do # this is wrong!, sigs are primary not the keys
    sig_keys
    |> Enum.with_index()
    |> Enum.reduce_while(
      [],
      fn {skey, sk_idx}, acc ->
        prio_next_key = Kerilex.Crypto.hash_and_encode!(skey)
        found_at = Enum.find_index(prio_next_keys, &Kernel.==(&1, prio_next_key))

        find_in_sigs(sk_idx, found_at, idx_ctrl_sigs)
        |> case do
          {:error, _} = res ->
            {:halt, res}

          oind ->
            {:cont, [{sk_idx, oind} | acc]}
        end
      end
    )
    |> case do
      {:error, _} = res ->
        res

      res ->
        # reverse and trasform for consuption by KeyTally
        {:ok,
         Enum.reduce(res, {[], []}, fn {cur_idx, prio_next_idx}, {cur_idxs, pn_idxs} ->
           {[cur_idx | cur_idxs], [prio_next_idx | pn_idxs]}
         end)}
    end
  end

  def sig_idx_pairs(sig_keys, idx_ctrl_sigs, _pnk) do
    {:error,
     "length of the signing 'k' list (#{length(sig_keys)}) differs from the number of attached sigs (#{length(idx_ctrl_sigs)})"}
  end

  defp find_in_sigs(_sk_idx, nil, _idx_ctrl_sigs) do
    # this key is completely new!
    nil
  end

  defp find_in_sigs(sk_idx, found_at, idx_ctrl_sigs) do
    Enum.find_value(idx_ctrl_sigs, fn %IndexedControllerSig{ind: ind, oind: oind} ->
      cond do
        ind != sk_idx ->
          nil

        ind == sk_idx and (oind == found_at or oind == nil) ->
          # sigs whose key has the same index in both lists don't produce oind
          oind || found_at

        ind == sk_idx and oind != found_at ->
          {:error,
           "mismatch: prio next key found at ind(#{found_at}), indexed controller signature oind(#{oind || "nil"})"}
      end
    end)
  end

  def new_backers(prev_backers, rot_ba, rot_br, rot_bt ) do
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
