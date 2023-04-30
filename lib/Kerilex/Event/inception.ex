defmodule Kerilex.Event.Inception do
  @moduledoc """
    Implements KERI `icp` event logic
  """

  import Kerilex.Constants
  import Comment
  alias Kerilex.Event
  alias Jason.OrderedObject, as: OO

  @ilk "icp"

  const(ilk, @ilk)

  comment("""
   example of Gleif Root pre icp
  {
    "v": "KERI10JSON00049d_",
    "t": "icp",
    "d": "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
    "i": "EDP1vHcw_wc4M__Fj53-cJaBnZZASd-aMTaSyWEQ-PC2",
    "s": "0", <- Note: this is a hex value!
    "kt": [
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3"
    ],
    "k": [
      "DFkI8OSUd9fnmdDM7wz9o6GT_pJIvw1K_S21AKZg4VwK",
      "DA-vW9ynSkvOWv5e7idtikLANdS6pGO2IHJy7v0rypvE",
      "DLWJrsKIHrrn1Q1jy2oEi8Bmv6aEcwuyIqgngVf2nNwu",
      "DD6JYvXBsVAmEtirgwKPQBHFwVQfX4f_CZQmBsOh_1hT",
      "DOOyxiELz2xqQCebeimJC4PW9Xv_5xgRkW7q_TC2lToN",
      "DGoS9UZrs0u2jiCMlMGAG5xpUwQQ66NyqEoxmq8OiFUT",
      "DBaAts7zYaRUNMkWIgWN5TL85cp61mHk_wlWzsIM-cc_"
    ],
    "nt": [
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3",
      "1/3"
    ],
    "n": [ <- pre-rotated keys's digests ( of qb4 of a digegst, "Dxxx..")
      "EB_KZDNru1dlUb_Nk0EpxbU1ZDSNUO790RAZ_-ehCwR6",
      "EHgOexUh8AvN7rXblsSr6MJE5Gn1HPq5Mv9KFpCpllKN",
      "ECH4pTtUI653ykKb_capPBkKF3RvBZRzyb5dPfuJCfOf",
      "ELXXiPwoaWOVOTLMOAmg4IKkjFHFs3q2hsL9tHvuuC2D",
      "EAcNrjXFeGay9qqMj96FIiDdXqdWjX17QXzdJvq58Zco",
      "ELzkbNYyJkwSa3HTua5eZwIeqiDmJBbUEgQ1a0sHtld_",
      "EPoly9Tq4IPx41U-AGDShLDdtbFVzt7EqJUHmCrDxBdb"
    ],
    "bt": "4",
    "b": [
      "BNfDO63ZpGc3xiFb0-jIOUnbr_bA-ixMva5cZb3s4BHB",
      "BDwydI_FJJ-tvAtCl1tIu_VQqYTI3Q0JyHDhO1v2hZBt",
      "BGYJwPAzjyJgsipO7GY9ZsBTeoUJrdzjI2w_5N-Nl6gG",
      "BM4Ef3zlUzIAIx-VC8mXziIbtj-ZltM8Aor6TZzmTldj",
      "BLo6wQR73-eH5v90at_Wt8Ep_0xfz05qBjM3_B1UtKbC"
    ],
    "c": [ <- configuration for the prefix, can be:
      "EO" <- 'EO' Only allow establishment events
              'DND' Dot not allow delegated identifiers
              'NB'  Do not allow any backers for registry
    ],
    "a": [] <- seals' objects.
  }

  """)

  comment("""
   example of a witness ( non-trans prefix)'s inception
  {
    "v": "KERI10JSON0000fd_",
    "t": "icp",
    "d": "EDyvAMpba1ZJbgvwxb6hUBsycgsQfxUdk-Yi2AYod4k7",
    "i": "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO",
    "s": "0",
    "kt": "1",
    "k": [
      "BP-nOCxB--MKSgwTXyLj01zA5jkG0Gb-8h-SHDX4qCJO"
    ],
    "nt": "0",
    "n": [],
    "bt": "0",
    "b": [],
    "c": [],
    "a": []
  }

  """)

  @conf_eo :eo
  @conf_dnd :dnd
  @conf_nb :nb

  @config_opts %{@conf_dnd => "DND", @conf_eo => "EO", @conf_nb => "NB"}

  def encode(kts, keys, nts, next_key_digs, backers) do
    {:ok, eo} = event_obj(kts, keys, nts, next_key_digs, backers)

    eo
    |> Event.serialize()
  end

  def encode(<<"B", _::binary-size(43)>> = nt_pref) do
    {:ok, bo} =
      event_obj(
        "1",
        [nt_pref],
        "0",
        [],
        [],
        false
      )

    bo
    |> Event.serialize()
  end

  def encode(pref) do
    {:error, "bad argument, required a non transferable prefix, got: #{pref} "}
  end

  defp event_obj(kts, keys, nts, next_key_digs, backers, trans \\ true) do
    msg_vals = [
      v: Event.keri_version_str(),
      t: ilk(),
      d: "",
      i: if(trans, do: "", else: keys |> hd),
      s: "0",
      kt: kts,
      k: keys,
      nt: nts,
      n: next_key_digs,
      bt: length(backers) |> Integer.to_string(),
      b: backers,
      c: [],
      a: []
    ]

    {:ok, OO.new(msg_vals)}
  end
end
