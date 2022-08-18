# priv/repo/migrations/20220818132000_foo_user_migration.exs
defmodule App.Migrations.FooUserMigration do
  use Ecto.Migration

  def change do
    create table("foos") do
      add :foo_x, :string
      add :foo_y, :integer
      add :foo_z, :float
    end

    create table("users") do
      add(:nickname, :string)
      add(:email, :string)
      add(:password, :string)
    end
  end
end

# priv/repo/migrations/20220818132500_herodotus_action_migration.exs
defmodule App.Migrations.HerodotusActionMigration do
  use Herodotus.Migration, users_table: :users
end

# lib/app/accounts/user.ex
defmodule App.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Note that the users table name matches the one created in the
  # herodotus action migration
  schema "users" do
    field(:nickname, :string)
    field(:email, :string)
    field(:password, :string)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname, :email, :password])
    |> validate_required([:name, :email, :password])
  end
end


# lib/app/foo_bar/foo.ex
defmodule App.FooBar.Foo do
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

# lib/app/foo_bar.ex
defmodule App.FooBar do
  import Ecto.Query, warn: false

  alias App.Repo

  # Use herodotus and tell it where to get the action schema
  # and the repo where we will log the actions
  # (it should probably be the same repo as the one you're using
  # to save the rest of your data, but that's in no way required)
  use Herodotus,
   action_schema: App.HerodotusAction,
   repo: App.Repo

  # Don't track this one, unless you really want to log accesses
  def get_foo!(id) do
    FooBarRepo.get!(Foo, id)
  end

  # A `Herodotus.track do ... end` block can include several functions.
  Herodotus.track do
    def create_foo(attrs \\ %{}) do
      %Foo{}
      |> Foo.changeset(attrs)
      |> FooBarRepo.insert()
    end

    def update_foo(%Foo{} = foo, attrs) do
      foo
      |> Foo.changeset(attrs)
      |> FooBarRepo.update()
    end
  end

  # Or it can track a single function
  Herodotus.track do
    def delete_foo(%Foo{} = foo) do
      FooBarRepo.delete(foo)
    end
  end

  # This function doesn't even hit the database, it's a pure function.
  # No need to track it...
  def change_foos(%Foo{} = foo) do
    Foo.changeset(foo, %{})
  end
end

attrs = %{foo_x: "X1", foo_y: 1, foo_z: 1.0}
      delta_attrs = %{foo_x: "X1_updated"}
      # First, create a foo so that we have something to update
      {:ok, %Foo{} = foo} = FBWD.create_foo(attrs)
      # Update the foo
      {:ok, %Foo{} = foo_updated} = FBWD.update_foo(foo, delta_attrs)

      actions = FooBarRepo.all(Query.from HerodotusAction, order_by: [asc: :timestamp])

      assert [action_create, action_update] = actions

      # Check the parameters of the "create" action
      assert action_create.module == FBWD
      assert action_create.function == :create_foo
      assert action_create.arity == 1
      assert action_create.resource_schema == Foo
      assert action_create.resource_id == foo.id
      assert action_create.arguments == [attrs]
      assert action_create.arguments_persisted == true
      assert action_create.result == {:ok, foo}
      assert action_create.result_persisted == true

      # Check the parameters of the "update" action
      assert action_update.module == FBWD
      assert action_update.function == :update_foo
      assert action_update.arity == 2
      assert action_update.resource_schema == Foo
      assert action_update.resource_id == foo_updated.id
      assert action_update.arguments == [foo, delta_attrs]
      assert action_update.arguments_persisted == true
      assert action_update.result == {:ok, foo_updated}
      assert action_update.result_persisted == true

[
  %HerodotusTest.TestFixtures.HerodotusAction{
    __meta__: #Ecto.Schema.Metadata<:loaded, "herodotus_actions">,
    arguments: [%{foo_x: "X1", foo_y: 1, foo_z: 1.0}],
    arguments_persisted: true,
    arity: 1,
    function: :create_foo,
    id: "5388d9e2-deca-4a2b-b682-745156e489a9",
    module: HerodotusTest.TestFixtures.FooBarWithDecorators,
    resource_id: 1,
    resource_schema: HerodotusTest.TestFixtures.Foo,
    result: {:ok,
      %HerodotusTest.TestFixtures.Foo{
        __meta__: #Ecto.Schema.Metadata<:loaded, "foos">,
        foo_x: "X1",
        foo_y: 1,
        foo_z: 1.0,
        id: 1
      }},
    result_persisted: true,
    timestamp: ~U[2022-08-18 13:35:16.366470Z],
    user: #Ecto.Association.NotLoaded<association :user is not loaded>,
    user_id: nil
  },
  %HerodotusTest.TestFixtures.HerodotusAction{
    __meta__: #Ecto.Schema.Metadata<:loaded, "herodotus_actions">,
    arguments: [
      %HerodotusTest.TestFixtures.Foo{
        __meta__: #Ecto.Schema.Metadata<:loaded, "foos">,
        foo_x: "X1",
        foo_y: 1,
        foo_z: 1.0,
        id: 1
      },
      %{foo_x: "X1_updated"}
    ],
    arguments_persisted: true,
    arity: 2,
    function: :update_foo,
    id: "d23c8042-7fcf-420b-9f95-a34c91cfce35",
    module: HerodotusTest.TestFixtures.FooBarWithDecorators,
    resource_id: 1,
    resource_schema: HerodotusTest.TestFixtures.Foo,
    result: {:ok,
      %HerodotusTest.TestFixtures.Foo{
        __meta__: #Ecto.Schema.Metadata<:loaded, "foos">,
        foo_x: "X1_updated",
        foo_y: 1,
        foo_z: 1.0,
        id: 1
      }},
    result_persisted: true,
    timestamp: ~U[2022-08-18 13:35:16.367259Z],
    user: #Ecto.Association.NotLoaded<association :user is not loaded>,
    user_id: nil
  }
]
