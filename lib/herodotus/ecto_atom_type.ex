defmodule Herodotus.EctoAtomType do
  @moduledoc """
  An ecto type that stores an atom as an string.
  Elixir module names are NOT represented in a special way.
  The `Module` atom will be represented as `"Elixir.Module"`.

  This ecto type is unsafe! Never use on user-provided input.
  Reading this field from a database may lead to generation of atoms at runtime.
  """

  use Ecto.Type

  @doc false
  def type, do: :string

  # Provide custom casting rules.

  @doc false
  def cast(string) when is_binary(string) do
    {:ok, String.to_atom(string)}
  end

  @doc false
  def cast(atom) when is_atom(atom) do
    {:ok, atom}
  end

  @doc false
  def cast(_), do: :error

  def load(data) when is_binary(data) do
    atom = String.to_atom(data)
    {:ok, atom}
  end

  @doc false
  def dump(atom) when is_atom(atom), do: {:ok, to_string(atom)}
  def dump(_), do: :error
end
