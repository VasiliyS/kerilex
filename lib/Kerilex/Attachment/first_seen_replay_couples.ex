defmodule Kerilex.Attachment.FirstSeenReplayCouples do
  @moduledoc """
    encoding and decoding of "-E##" counter code:
    0AAAAAAAAAAAAAAAAAAAAAAA1AAG2022-11-30T18c57c00d813914p00c00
    Composed Base64 Couple, fnu+dt
  """

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.ReplayCouple

  @code "-E"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  def parse(<<@code, couple_count::binary-size(2), att_rest::bitstring>>) do
    with {:ok, rc_count} <- B64.b64_to_int(couple_count),
         {:ok, rc_list, att_rest} <- get_replay_couples(rc_count, att_rest, []) do
      {:ok, rc_list, att_rest}
    else
      error ->
        error
    end
  end

  defp get_replay_couples(0, att_rest, rcl) do
    {:ok, Enum.reverse(rcl), att_rest}
  end

  defp get_replay_couples(count, att_rest, rcl) do
    case ReplayCouple.parse(att_rest) do
      {:ok, rc, att_rest} ->
        get_replay_couples(count - 1, att_rest, [rc | rcl])

      error ->
        error
    end
  end
end
