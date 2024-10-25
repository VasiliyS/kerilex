defmodule Watcher.DidWebs.Producer.JsonEncoder do
  @moduledoc """
  defines a simple keyword based json encoder based on erlang's new`json` module

  The idea is to avoid creating `Jason.OrderedObject`'s while constructing the did doc
  """

  @spec ordered_json(keyword()) :: iodata()
  def ordered_json([{_, _} | _] = keyword_list) do
    :json.encode(keyword_list, &encoder/2)
  end

  defp encoder([{_, _} | _] = list, encoder), do: :json.encode_key_value_list(list, encoder)
  defp encoder(val, encoder), do: :json.encode_value(val, encoder)
end

defmodule Watcher.DidWebsProducer do
  @moduledoc """
  generate a valid `JSON` representation (DID document) of a supplied AID key state
  according to the draft of the `did:webs` method.

  https://trustoverip.github.io/tswg-did-method-webs-specification/
  """
  alias Kerilex.Crypto
  alias Kerilex.Crypto.WeightedKeyThreshold
  alias Kerilex.Crypto.KeyThreshold
  alias Watcher.KeyState
  alias Watcher.DidWebs.Producer.JsonEncoder

  @did_webs "did:webs"
  @conditional_proof "ConditionalProof2022"
  @json_web_key "JsonWebKey"

  @spec did_document(Kerilex.pre(), Watcher.KeyState.t(), [{:base_url, String.t()}]) ::
          {:error, String.t()} | {:ok, String.t()}
  def did_document(aid, %KeyState{} = ks, opts) do
    base_url = Keyword.fetch!(opts, :base_url)

    with {:ok, id} <- build_id(aid, base_url),
         {:ok, ver_methods} <- build_verification_methods(ks, id, aid) do
      generate_did_doc(id, ver_methods)
    end
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  def build_id(aid, base_url) do
    with {:ok, uri} <- URI.new(base_url) do
      id =
        uri
        |> add_method()
        |> add_host()
        |> add_port()
        |> add_path(aid)

      {:ok, id |> IO.iodata_to_binary()}
    end
  end

  defp add_method(uri) do
    {[@did_webs, ":"], uri}
  end

  defp add_host({id_data, uri}) do
    case uri.host do
      host when host != nil and host != "" ->
        {[id_data, host], uri}

      _ ->
        raise ArgumentError, "bad url, must have host"
    end
  end

  defp add_port({id_data, uri}) do
    case uri.port do
      port when port == nil or port == 80 or port == 443 ->
        {[id_data], uri}

      port ->
        {[id_data, "%3A", Integer.to_string(port)], uri}
    end
  end

  defp add_path({id_data, uri}, aid) do
    case uri.path do
      path when path != nil and path != "/" ->
        path =
          path
          |> String.trim("/")
          |> String.replace("/", ":")

        [id_data, ":", path, ":", aid]

      _ ->
        [id_data, ":", aid]
    end
  end

  defp build_verification_methods(%KeyState{} = ks, id, aid) do
    ver_methods =
      case ks.kt do
        %KeyThreshold{threshold: kt} when kt > 1 ->
          [cond_threshold(ks.kt, ks.k, id, aid) | ver_methods(ks.k, id)]

        %KeyThreshold{} = _threshold ->
          ver_methods(ks.k, id)

        %WeightedKeyThreshold{} = kt ->
          [cond_threshold(kt, ks.k, id, aid) | ver_methods(ks.k, id)]
      end

    {:ok, ver_methods}
  end

  defp cond_threshold(threshold, k, id, aid) when is_integer(threshold) do
    [
      id: "#" <> aid,
      type: @conditional_proof,
      controller: id,
      threshold: threshold,
      conditionThreshold: Enum.map(k, fn key -> "#" <> key end)
    ]

    # |> Jason.OrderedObject.new()
  end

  defp cond_threshold(%WeightedKeyThreshold{} = kt, k, cid, aid) do
    common_denominator =
      if Ratio.denominator(kt.sum) == 1,
        do: Ratio.numerator(kt.sum),
        else: Ratio.denominator(kt.sum)

    [
      id: "#" <> aid,
      type: @conditional_proof,
      controller: cid,
      threshold: common_denominator,
      conditionWeightedThreshold:
        Enum.zip(kt.weights, k)
        |> Enum.filter(fn {w, _key} -> Ratio.numerator(w) != 0 end)
        |> Enum.map(fn {w, key} ->
          [
            condition: "#" <> key,
            weight: Ratio.numerator(w) * div(common_denominator, Ratio.denominator(w))
          ]

          # |> Jason.OrderedObject.new()
        end)
    ]

    # |> Jason.OrderedObject.new()
  end

  defp ver_methods(keys, controller_id) do
    for key <- keys, do: key_to_ver_method(key, controller_id)
  end

  defp key_to_ver_method(<<"D", _rest::binary-size(43)>> = key, controller_id) do
    {:ok, raw_key, :ed25519} = key |> Crypto.to_raw_key()

    [
      id: "#" <> key,
      type: @json_web_key,
      controller: controller_id,
      publicKeyJwk: [
        kid: key,
        kty: "OKP",
        crv: "Ed25519",
        x: raw_key |> Base.url_encode64(padding: false)
      ]
      # |> Jason.OrderedObject.new()
    ]

    # |> Jason.OrderedObject.new()
  end

  defp key_to_ver_method(key, _cid) do
    raise RuntimeError, "key type for key='#{key}' not implemented"
  end

  defp generate_did_doc(id, ver_methods) do
    ver_ids = get_ver_ids(ver_methods)

    json =
      [
        id: id,
        verificationMethod: ver_methods,
        authentication: ver_ids,
        assertionMethod: ver_ids
      ]
      # |> Jason.OrderedObject.new()
      # |> Jason.encode()
      |> JsonEncoder.ordered_json()
      |> IO.iodata_to_binary()

    {:ok, json}
  end

  defp get_ver_ids(ver_methods) do
    ver_method = hd(ver_methods)

    case ver_method[:type] do
      @json_web_key ->
        Enum.map(ver_methods, fn m -> m[:id] end)

      @conditional_proof ->
        [ver_method[:id]]
    end
  end
end
