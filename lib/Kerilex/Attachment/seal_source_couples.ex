defmodule Kerilex.Attachment.SealSourceCouples do
  @moduledoc """
    encoding and decoding of "-G##" counter code:
    Composed Base64 couple, snu+dig of given delegators or issuers event
  """

  alias Kerilex.Attachment.Number, as: B64
  alias Kerilex.Attachment.SealSourceCouple, as: SSC

  @code "-G"

  def code_match?(<<@code, _rest::bitstring>>), do: true
  def code_match?(<<_att::bitstring>>), do: false

  def parse(<<@code, couple_count::binary-size(2), att_rest::bitstring>>) do
    with {:ok, couple_count} <- B64.b64_to_int(couple_count),
         {:ok, _, _} = res <- get_couples(couple_count, att_rest, []) do
      res
    else
      error ->
        error
    end
  end

  defp get_couples(0, att_rest, sscl) do
    {:ok, Enum.reverse(sscl), att_rest}
  end

  defp get_couples(count, att_rest, sscl) do
    case SSC.parse(att_rest) do
      {:ok, ssc, att_rest} ->
        get_couples(count - 1, att_rest, [ssc | sscl])

      error ->
        error
    end
  end
end
