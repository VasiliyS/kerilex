defmodule Watcher.OOBI.IURL do
  @moduledoc """
  OOBI URL
  """

  @type t :: %__MODULE__{aid: Kerilex.pre(), url: String.t()}
  defstruct aid: "", url: ""

  # parse out aid prefix from the IURL and check 'witness' role
  @aid_re ~r/^\/oobi\/(?<aid>[-_a-zA-Z0-9]{44})/

  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(url) do
    uri = URI.new!(url)

    validate_uri!(uri)

    case Regex.run(@aid_re, uri.path, capture: [:aid]) do
      [aid] ->
        port = (uri.port && [":", Integer.to_string(uri.port)]) || ""
        url = [uri.scheme, "://", uri.host, port, "/oobi/", aid, "/witness"]
        {:ok, %__MODULE__{aid: aid, url: IO.iodata_to_binary(url)}}

      nil ->
        {:error, "bad format, AID prefix couldn't be found in the path: '#{uri.path}' "}
    end
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp validate_uri!(%URI{} = uri) do
    err_msg =
      cond do
        uri.scheme == nil ->
          "missing scheme"

        uri.host == "" ->
          "missing host"

        uri.path == nil ->
          "has no path"

        true ->
          nil
      end

    if err_msg, do: raise(ArgumentError, message: err_msg), else: :ok
  end
end

defmodule Watcher.OOBI.Resolver do
  @moduledoc """
  handle OOBI urls
  """
  require Logger
  alias Watcher.AIDMonitorReq
  alias Watcher.KeyStateStore
  alias Watcher.OOBI.IURL

  @type cesr_encoded_kel :: binary()

  @spec kel(iurl :: IURL.t()) :: {:ok, cesr_encoded_kel()} | {:error, String.t()}
  def kel(%IURL{url: url}) do
    Req.get(url)
    |> case do
      {:ok, resp} when resp.status == 200 ->
        {:ok, resp.body}

      {:ok, resp} ->
        {:error, "failed to get OOBI response from '#{url}', status='#{resp.status}'"}

      {:error, e} ->
        {:error, "failed to get OOBI response from '#{url}', exception: #{Exception.message(e)}"}
    end
  end

  @spec get_logs(Kerilex.pre()) :: {:error, map()} | {:ok, cesr_encoded_kel()} | :skip
  def get_logs(aid) do
    case get_random_witness_url(aid) do
      {:ok, url} ->
        do_get_logs(url, aid, false)

      {:no_endpoint, wit_aid} ->
        Logger.warning(%{msg: "url for witness not found", wit_aid: wit_aid, aid: aid})
        find_working_endpoint_and_request_logs(aid, wit_aid)

      {:error, _} = err ->
        handle_get_logs_error(err, %{})
    end
  end

  defp find_working_endpoint_and_request_logs(aid, wit_aid) do
    case find_witness_url(aid, wit_aid) do
      {:ok, url} ->
        Logger.info(%{msg: "requesting KEL with endpoints", witness: url, aid: aid})
        do_get_logs(url, aid, true)

      :not_found ->
        Logger.error(%{msg: "no endpoints found", aid: aid})
        :skip

      {:error, _} = err ->
        handle_get_logs_error(err, %{})
    end
  end

  defp do_get_logs(base_url, aid, update_endpoints?) do
    with req = AIDMonitorReq.new(base_url: base_url),
         oobi_path = if(update_endpoints?, do: "/oobi/#{aid}/witness", else: "/oobi/#{aid}"),
         resp = Req.get(req, url: oobi_path),
         {:ok, resp} <- (match?({:ok, _}, resp) && resp) || {:req_error, base_url, resp},
         :ok <- (resp.status == 200 && :ok) || {:bad_wit_response, resp.status, base_url} do
      {:ok, resp.body}
    else
      {:bad_wit_response, status, url} ->
        handle_get_logs_error({:error, "bad witness response status"}, %{
          url: url,
          status: status,
          aid: aid
        })

      error ->
        handle_get_logs_error(error, %{aid: aid})
    end
  end

  defp handle_get_logs_error({:error, _} = err, %{} = log_report) do
    report_get_logs_error(err, log_report)
  end

  defp handle_get_logs_error({:req_error, url, resp}, %{} = log_report) do
    report_get_logs_error(resp, Map.merge(%{wit_url: url}, log_report))
  end

  defp report_get_logs_error({:error, reason}, log_report) do
    msg = "failed to get logs, "

    msg =
      case reason do
        e when is_exception(e) ->
          msg <> Exception.message(e)

        reason when is_binary(reason) ->
          msg <> reason

        term ->
          msg <> inspect(term)
      end

    {:error, Map.put(log_report, :reason, msg)}
  end

  defp get_random_witness_url(aid) do
    action = fn wit_list ->
      Enum.random(wit_list)
      |> get_witness_url()
    end

    do_with_witness_list(aid, action)
  end

  defp find_witness_url(aid, missing_wit_aid) do
    action = fn wit_list ->
      wit_list
      |> Enum.reduce_while(
        :not_found,
        fn
          wit_aid, res when wit_aid != missing_wit_aid ->
            case get_witness_url(wit_aid) do
              {:ok, _url} = res ->
                {:halt, res}

              {:no_endpoint, wit_aid} ->
                Logger.error(%{msg: "url for witness not found", wit_aid: wit_aid, aid: aid})
                {:cont, res}

              {:error, _} = err ->
                {:halt, err}
            end

          _wit_aid, res ->
            {:cont, res}
        end
      )
    end

    do_with_witness_list(aid, action)
  end

  defp do_with_witness_list(aid, action) do
    case KeyStateStore.get_state(aid) do
      {:ok, state, _sn} ->
        action.(state.b)

      :not_found ->
        {:error, "key state for aid prefix='#{aid}' not found"}

      {:error, reason} ->
        {:error, "failed to get key state for aid='#{aid}', " <> reason}
    end
  end

  defp get_witness_url(wit_aid) do
    case KeyStateStore.get_backer_url(wit_aid) do
      {:ok, url, _introduced} ->
        {:ok, url}

      :not_found ->
        # {:error, "no url for witness with aid='#{wit_aid}' was found"}
        {:no_endpoint, wit_aid}

      {:error, reason} ->
        {:error, "failed to get url for the witness with aid='#{wit_aid}', " <> reason}
    end
  end

  # defp add_oobi(wit_url, aid) do
  #   with {:ok, uri} <- URI.new(wit_url) do
  #     url =
  #       URI.append_path(uri, "/oobi/#{aid}")
  #       |> URI.to_string()

  #     {:ok, url}
  #   end
  # end
end
