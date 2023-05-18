defmodule Kerilex.Crypto.KeyTally do
  @moduledoc """
  threshold logic for keys
  """
  alias Kerilex.Crypto.KeyThreshold, as: KT
  alias Kerilex.Crypto.WeightedKeyThreshold, as: WKT

  def new(m_of_n) when is_integer(m_of_n) do
    {:ok, %KT{threshold: m_of_n}}
  end

  def new(m_of_n) when is_binary(m_of_n) do
    m_of_n
    |> Integer.parse(16)
    |> case do
      {t, ""} ->
        {:ok, %KT{threshold: t}}

      {_t, _rest} ->
        {:error, "wanted hex integer, got: #{m_of_n}"}

      _error ->
        {:error, "bad argument, can't parse '#{m_of_n}' as hex integer"}
    end
  end

  def new(thresholds) when is_list(thresholds) do
    split_pattern = :binary.compile_pattern("/")

    if thresholds |> hd |> is_list do
      thresholds |> process_tr_clauses(split_pattern)
    else
      thresholds |> process_tr_clause(split_pattern)
    end
    |> case do
      {:error, reason} ->
        {:error, "failed to parse list of key thresholds: #{reason}"}

      {:ok, weights, sum} ->
        weights = weights |> Enum.reverse()
        size = length(weights)
        range = 0..(size - 1)

        {:ok,
         %WKT{
           size: size,
           weights: weights,
           sum: sum,
           ind_ranges: [range]
         }}

      {:ok, weights, sum, ioc} ->
        {:ok,
         %WKT{
           size: length(weights),
           weights: weights,
           sum: sum,
           ind_ranges: ioc
         }}
    end
  end

  def new(data) do
    {:error,
     "bad argument, got '#{data}', expected an integer, hex encoded integer string or a list of fractions"}
  end

  defp process_tr_clauses(tr_clauses, pattern) do
    tr_clauses
    |> Enum.reduce_while(
      {[], Ratio.new(0, 1), []},
      fn c, {weights, sum, ranges} ->
        c
        |> process_tr_clause(pattern)
        |> case do
          {:error, _} = err ->
            {:halt, err}

          {:ok, clause_weights, clause_sum} ->
            range = clause_weights |> clause_range(ranges)
            {:cont, {[clause_weights | weights], Ratio.add(sum, clause_sum), [range | ranges]}}
        end
      end
    )
    |> case do
      {:error, _} = err ->
        err

      {weights, sum, ranges} ->
        {:ok, weights |> List.flatten() |> Enum.reverse(), sum, Enum.reverse(ranges)}
    end
  end

  defp clause_range(key_weights, ranges) do
    calc_start = fn r ->
      r.last + 1
    end

    start_ind = if ranges == [], do: 0, else: ranges |> hd |> calc_start.()

    end_ind = start_ind + length(key_weights) - 1
    Range.new(start_ind, end_ind)
  end

  defp process_tr_clause(tr_clause, pattern) when is_list(tr_clause) do
    tr_clause
    |> Enum.reduce_while(
      [],
      fn tr, weights ->
        tr
        |> parse_threshold(pattern)
        |> case do
          {:error, _} = err ->
            {:halt, err}

          ratio ->
            {:cont, [ratio | weights]}
        end
      end
    )
    |> validate_clause
  end

  defp process_tr_clause(tr_clause, _pattern) do
    {:error, "clause should be a list of fractional weights, got: #{inspect(tr_clause)}"}
  end

  defp validate_clause({:error, _} = err), do: err

  defp validate_clause(ratios) do
    ratios
    |> Enum.reduce_while(
      Ratio.new(0, 1),
      fn r, sum ->
        if Ratio.gt?(r, 1) or Ratio.lt?(r, 0) do
          {:halt, {:error, "bad weight, should be 0 <= w <= 1, got: '#{Ratio.to_string(r)}'"}}
        else
          {:cont, Ratio.add(r, sum)}
        end
      end
    )
    |> case do
      {:error, _} = err ->
        err

      sum ->
        if Ratio.lt?(sum, 1) do
          {:error, "sum of key thresholds is < 1"}
        else
          {:ok, ratios, sum}
        end
    end
  end

  defp parse_threshold(ratio, pattern) when is_binary(ratio) do
    :binary.split(ratio, pattern, [:trim_all])
    |> Enum.map(&Integer.parse/1)
    |> case do
      [{n, ""}, {d, ""}] ->
        Ratio.new(n, d)

      [{n, ""}] ->
        Ratio.new(n, 1)

      _ ->
        {:error, "failed to parse '#{ratio}' as fraction"}
    end
  end

  defp parse_threshold(data, _pattern) do
    {:error, "expected ratio encoded in a string, got: '#{inspect(data)}'"}
  end

  ################   threshold validation methods ###########################

  def satisfy?(%KT{threshold: t}, key_indices) when is_list(key_indices) do
    if length(key_indices) >= t, do: true, else: false
  end

  def satisfy?(%WKT{} = kt, key_indices) when is_list(key_indices) do
    indices = key_indices |> Enum.uniq() |> Enum.sort()

    if kt.size < length(indices) do
      false
    else
      check_tally(kt, indices)
    end
  end

  defp check_tally(%WKT{} = kt, indices) when length(kt.ind_ranges) > 1 do
    kt.ind_ranges
    |> Enum.reduce_while(
      false,
      fn range, _check ->
        clause_indices = indices |> Stream.filter(&Enum.member?(range, &1))

        if clause_threshold_satisfied?(kt, clause_indices) do
          {:cont, true}
        else
          {:halt, false}
        end
      end
    )
  end

  defp check_tally(%WKT{} = kt, indices) do
    clause_threshold_satisfied?(kt, indices)
  end

  defp clause_threshold_satisfied?(%WKT{} = kt, indices) do
    indices
    |> Enum.reduce_while(
      Ratio.new(0, 1),
      fn i, sum ->
        Enum.at(kt.weights, i)
        |> case do
          nil ->
            {:halt, :error}

          r ->
            {:cont, Ratio.add(sum, r)}
        end
      end
    )
    |> case do
      :error ->
        false

      sum ->
        Ratio.gte?(sum, 1)
    end
  end
end
