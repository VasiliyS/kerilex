defmodule Kerilex.Attachment.Count do
  @moduledoc """
    defines primitives to deal with Keri's "counter"
    codes, e.g. -V##, -C##, etc.
    TODO(VS): deprecate, all counter logic is handled in specific types
    e.g.: IndexedControllerSigs, etc.
  """
  alias Kerilex.Attachment.Number

  def to_material_quadlets(size)
      when rem(size, 4) == 0 do
    case div(size, 4) |> Number.int_to_b64(maxpadding: 2) do
      {:ok, b64} ->
        {:ok, "-V" <> b64}

      _ ->
        {:error, "max is #{4095 * 4}, got #{size}"}
    end
  end

  def to_nontrans_receipts_couples(count) do
    case count |> Number.int_to_b64(maxpadding: 2) do
      {:ok, b64} ->
        {:ok, "-C" <> b64}

      _ ->
        {:error, "max is #{4095 * 4}, got #{count}"}
    end
  end
end
