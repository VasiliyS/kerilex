defmodule Kerilex.Attachment.ReplayCouple do
  @moduledoc """
    Deals with replay couples: \n
      ex: 0AAAAAAAAAAAAAAAAAAAAAAA1AAG2022-11-21T17c21c27d010057p00c00 \n
      snu+dig of given delegators or issuers event
  """

  alias Kerilex.Attachment.Number
  alias Kerilex.DateTime, as: KDT

  # defstruct fsn: nil, dt: nil

  def parse(<<att::bitstring>>) do
    with {:ok, sn, att_rest} <- parse_fn(att),
         {:ok, dt, att_rest} <- parse_dt(att_rest) do
      # {:ok, %__MODULE__{fsn: sn, dt: dt}, att_rest}
      {:ok, {sn, dt}, att_rest}
    end
  end

  defp parse_fn(<<"0A", sn::binary-size(22), att_rest::bitstring>>) do
    sn
    |> Number.b64_to_int()
    |> case do
      {:ok, fsn} ->
        {:ok, fsn, att_rest}

      error ->
        error
    end
  end

  defp parse_dt(<<"1AAG", dt::binary-size(32), att_rest::bitstring>>) do
    case KDT.parse(dt) do
      # TODO(VS): shouldn't we always use UTC?
      {:ok, pdt, _offset} ->
        {:ok, pdt, att_rest}

      error ->
        error
    end
  end
end
