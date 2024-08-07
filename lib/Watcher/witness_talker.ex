defmodule Watcher.WitnessTalker do
  @moduledoc """
    Provides interface to send data and requests, as well as receive responses form a KERI witness
    uses HTTP
  """
  require Logger
  defstruct wit_pre: nil, url: nil, req: nil

  @wit_req_headers [{"Accept-Encoding", "identity"}, {"Content-Type", "application/cesr+json"}]
  @cesr_mtype "Cesr-Attachment"

  def new(pre, url) do
    req = Finch.build(:post, url, @wit_req_headers)
    %__MODULE__{wit_pre: pre, url: url, req: req}
  end

  def child_spec do
    {
      Finch,
      name: __MODULE__
      # options, see - https://hexdocs.pm/finch/Finch.html#start_link/1
    }
  end

  def send_request(%__MODULE__{req: req}, msg, cesr_att) do
    headers = [{@cesr_mtype, cesr_att}] ++ req.headers

    %Finch.Request{req | body: msg, headers: headers}
    |> Finch.request(__MODULE__)
    |> process_wit_resp()
  end

  defp process_wit_resp(resp) do
    case resp do
      {:ok, %Finch.Response{status: status}} ->
        if status == 204 do
          :ok
        else
          {:error, "request was not accepted by the witness, status=#{status}"}
        end
      {:error, exception} ->
        {:error, "failed to communicate with the witness, error='#{inspect(exception)}'"}
    end
  end

  def stream_request(%__MODULE__{req: req}, msg, cesr_att) do
    headers = [{@cesr_mtype, cesr_att}] ++ req.headers
    req = %Finch.Request{req | body: msg, headers: headers}

    fun = fn
      {:status, status}, acc ->
        IO.puts("status: #{status}")
        %{acc | status: status}

      {:headers, headers}, acc ->
        IO.puts("headers: #{inspect(headers)}")

        case acc[:headers] do
          nil -> %{acc | headers: headers}
          eh -> %{acc | headers: headers ++ eh}
        end

      {:data, data}, %{data: acc_data} = acc ->
        IO.puts("data: #{data}")
        %{acc | data: [data | acc_data]}
    end

    req
    |> Finch.stream(__MODULE__, %{status: nil, headers: nil, data: nil}, fun,
      receive_timeout: 60_000
    )
  end

  def poll_mbx!(%__MODULE__{req: req}, mbx_qry, qry_cesr_att, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    handler = Keyword.get(opts, :chunk_handler)

    handler =
      cond do
        handler == nil ->
          &default_chunk_handler/2

        is_function(handler, 1) ->
          do_build_handler(handler)

        true ->
          raise ArgumentError, message: "handler option should be an arity 1 function"
      end

    headers = [{@cesr_mtype, qry_cesr_att}] ++ req.headers
    req = %Finch.Request{req | body: mbx_qry, headers: headers}

    ref = req |> Finch.async_request(__MODULE__, receive_timeout: timeout * 2)
    # Time.utc_now()
    start = System.monotonic_time(:millisecond)

    do_poll_receive(ref, [], start, timeout, handler)
  end

  defp default_chunk_handler(data_acc, chunk) do
    if(data_acc == [], do: [chunk], else: [data_acc | chunk])
  end

  defp do_build_handler(handler) when is_function(handler, 1) do
    fn _acc, chunk ->
      worker = fn ->
       :ok = handler.(chunk)
      end

      #TODO(VS): consider using Task.Supervisor to control shutdown, errors, etc.
      {:ok, _} = Task.start(worker)
      []
    end
  end

  defp drain_mailbox(ref) do
    receive do
      {^ref, _} ->
        drain_mailbox(ref)
    after
      0 ->
        :ok
    end
  end

  defp do_poll_receive(ref, data_acc, _start, 0, _handler) do
    Finch.cancel_async_request(ref)
    drain_mailbox(ref)
    {:ok, data_acc}
  end

  # when deadline > 0 and is_function(handler, 2)
  defp do_poll_receive(ref, data_acc, start, deadline, handler) do
    Logger.debug("[WitnessTalker.do_poll_receive] start: '#{inspect(start)}, deadline: '#{deadline}'")
    receive do
      {^ref, :done} ->
        {:ok, data_acc}

      {^ref, {:data, chunk}} ->
        deadline = deadline - (System.monotonic_time(:millisecond) - start)
        deadline = if(deadline > 0, do: deadline, else: 0)
        do_poll_receive(ref, handler.(data_acc, chunk), start, deadline, handler)

      {^ref, {:error, _exception} = err} ->
        drain_mailbox(ref)
        err
    after
      deadline ->
        Logger.debug("[WitnessTalker.do_poll_receive] hit deadline: '#{deadline}'")
        do_poll_receive(ref, data_acc, start, 0, handler)
    end
  end
end
