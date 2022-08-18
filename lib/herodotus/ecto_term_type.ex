defmodule Herodotus.EctoTermType do
  @moduledoc """
  An ecto type that stores a term in ETF as a binary.

  This ecto type is unsafe! Never use on user-provided input.
  Reading this field from a database may lead to generation of atoms at runtime.
  """

  use Ecto.Type

  @doc false
  def type, do: :binary

  # Provide custom casting rules.

  @doc false
  def cast(string) when is_binary(string) do
    {:ok, :erlang.binary_to_term(string)}
  end

  def cast(term) do
    {:ok, term}
  end

  @doc false
  def load(data) when is_binary(data) do
    term = :erlang.binary_to_term(data)
    {:ok, term}
  end

  @doc false
  def dump(term), do: {:ok, :erlang.term_to_binary(term)}
end
