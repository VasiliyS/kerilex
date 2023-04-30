defmodule Watcher.MintWitnessTalker do
  @moduledoc """
    Provides interface to send data and requests, as well as receive responses form a KERI witness
    uses HTTP
  """
  defstruct wit_pre: nil, url: nil, req: nil

  @wit_req_headers [{"Accept-Encoding", "identity"}, {"Content-Type", "application/cesr+json"}]
  @cesr_mtype "Cesr-Attachment"
  def new(pre, url) do
    req = Finch.build(:post, url, @wit_req_headers)
    %__MODULE__{wit_pre: pre, url: url, req: req}
  end

  def child_spec(%__MODULE__{url: url}) do
    {Finch,
     name: __MODULE__,
     pools: %{
       # pool config options https://hexdocs.pm/finch/Finch.html#start_link/1
       # see connection options: :conn_opts https://hexdocs.pm/mint/1.4.0/Mint.HTTP.html#connect/4
       url => [size: 2]
     }}
  end

  def send_request(%__MODULE__{req: req}, msg, cesr_att) do
    headers = [{@cesr_mtype, cesr_att}] ++ req.headers

    %Finch.Request{req | body: msg, headers: headers}
    |> Finch.request(__MODULE__)
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

    req |> Finch.stream(__MODULE__, %{status: nil, headers: nil, data: nil}, fun, receive_timeout: 3 * 60_000)
  end
end
