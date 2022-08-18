defmodule HerodotusTest.TestFixtures.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field(:nickname, :string)
    field(:email, :string)
    field(:password, :string)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname, :email, :password])
    |> validate_required([:nickname, :email, :password])
  end
end
