defmodule HerodotusTest.TestFixtures.Bar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bars" do
    field(:bar_x, :string)
    field(:bar_y, :integer)
    field(:bar_z, :float)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:bar_x, :bar_y, :bar_z])
    |> validate_required([:bar_x, :bar_y, :bar_z])
  end
end
