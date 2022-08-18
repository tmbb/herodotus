defmodule HerodotusTest.TestFixtures.Foo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "foos" do
    field(:foo_x, :string)
    field(:foo_y, :integer)
    field(:foo_z, :float)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:foo_x, :foo_y, :foo_z])
    |> validate_required([:foo_x, :foo_y, :foo_z])
  end
end
