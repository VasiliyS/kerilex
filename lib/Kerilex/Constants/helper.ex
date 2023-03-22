defmodule Kerilex.Constants do
  defmacro const(const_name, const_value) do
    quote do
      def unquote(const_name), do: unquote(const_value)
    end
  end
end
