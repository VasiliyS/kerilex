defmodule Kerilex.DateTime do
  @moduledoc """
    defines convenience functions to generate DateTime
    strings in the "KERI" format
  """

  @keri_dt_format "%Y-%m-%dT%H:%M:%S.%f+00:00"

  def to_string(dt \\ DateTime.now!("Etc/UTC"))
      when is_struct(dt, DateTime) do
    dt
    |> Calendar.strftime(@keri_dt_format)
  end

  #@rep_chars  :binary.compile_pattern(["c", "d", "p"])

  def parse(enc_dt_str) do
      enc_dt_str
      |> String.replace(["c", "d", "p"], fn c ->
        case c do
          "c" -> ":"
          "p" -> "+"
          "d" -> "."
        end
      end)
      |> DateTime.from_iso8601()
  end
end
