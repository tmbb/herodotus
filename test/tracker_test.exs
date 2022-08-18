defmodule HerodotusTest.TrackerTest do
  use ExUnit.Case
  doctest Herodotus

  require Ecto.Query, as: Query

  alias HerodotusTest.Setup

  alias HerodotusTest.TestFixtures.{
    FooBarRepo,
    Foo,
    User,
    HerodotusAction,
    HerodotusActionMigration,
    UserMigration,
    FooBarMigration
  }

  alias HerodotusTest.TestFixtures.FooBarWithDecorators, as: FBWD

  setup_all do
    migrations = [
      FooBarMigration,
      UserMigration,
      HerodotusActionMigration
    ]

    Setup.setup_test_database(Ecto.Adapters.SQLite3, FooBarRepo, migrations)

    on_exit(fn ->
      Setup.teardown_test_database(Ecto.Adapters.SQLite3, FooBarRepo)
    end)
  end

  setup do
    FooBarRepo.delete_all(Query.from Foo)
    FooBarRepo.delete_all(Query.from User)
    FooBarRepo.delete_all(Query.from HerodotusAction)

    :ok
  end

  describe "create resource -" do
    test "creates a foo successfully and retreives it" do
      # Create a foo
      {:ok, %Foo{} = foo} = FBWD.create_foo(%{foo_x: "X1", foo_y: 1, foo_z: 1.0})
      # Retreive the foo from the database
      assert FooBarRepo.all(Foo) == [foo]
    end

    test "creates two foos successfully and retreives them" do
      # Create a foo
      {:ok, %Foo{} = foo1} = FBWD.create_foo(%{foo_x: "X1", foo_y: 1, foo_z: 1.0})
      {:ok, %Foo{} = foo2} = FBWD.create_foo(%{foo_x: "X2", foo_y: 2, foo_z: 2.0})
      # Check that we get the right foos
      foos = [foo1, foo2]
      retreived_foos = FooBarRepo.all(Foo)
      assert Enum.sort(foos) == Enum.sort(retreived_foos)
    end

    test "creating a foo logs an action with the right fields" do
      attrs = %{foo_x: "X1", foo_y: 1, foo_z: 1.0}
      {:ok, %Foo{} = foo} = FBWD.create_foo(attrs)
      [action] = FooBarRepo.all(Query.from HerodotusAction)

      assert action.module == FBWD
      assert action.function == :create_foo
      assert action.arity == 1
      assert action.resource_schema == Foo
      assert action.resource_id == foo.id
      assert action.arguments == [attrs]
      assert action.arguments_persisted == true
      assert action.result == {:ok, foo}
      assert action.result_persisted == true
    end
  end

  describe "update resource -" do
    test "updates a foo successfully and retreives it" do
      # First, create a foo so that we have something to update
      {:ok, %Foo{} = foo} = FBWD.create_foo(%{foo_x: "X1", foo_y: 1, foo_z: 1.0})
      # Update the foo
      {:ok, %Foo{} = foo_updated} = FBWD.update_foo(foo, %{foo_x: "X1_updated"})
      # Retreive the foo from the database; check it has updated correctly
      assert FooBarRepo.all(Foo) == [foo_updated]
    end

    test "creates and updates a foo; this generates two actions" do
      attrs = %{foo_x: "X1", foo_y: 1, foo_z: 1.0}
      delta_attrs = %{foo_x: "X1_updated"}
      # First, create a foo so that we have something to update
      {:ok, %Foo{} = foo} = FBWD.create_foo(attrs)
      # Update the foo
      {:ok, %Foo{} = foo_updated} = FBWD.update_foo(foo, delta_attrs)

      actions = FooBarRepo.all(Query.from HerodotusAction, order_by: [asc: :timestamp])

      IO.inspect(actions)

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
    end
  end

  describe "delete resource -" do
    test "deletes a foo successfully" do
      # First, create a foo so that we have something to update
      {:ok, %Foo{} = foo} = FBWD.create_foo(%{foo_x: "X1", foo_y: 1, foo_z: 1.0})
      # Update the foo
      {:ok, %Foo{}} = FBWD.delete_foo(foo)
      # The foo has been deleted; there are no more rows in that table
      assert FooBarRepo.all(Foo) == []
    end

    test "creates and deletes a foo; this generates two actions" do
      attrs = %{foo_x: "X1", foo_y: 1, foo_z: 1.0}
      # First, create a foo so that we have something to update
      {:ok, %Foo{} = foo} = FBWD.create_foo(attrs)
      # Update the foo
      {:ok, %Foo{} = foo_deleted} = FBWD.delete_foo(foo)

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
      assert action_update.function == :delete_foo
      assert action_update.arity == 1
      assert action_update.resource_schema == Foo
      assert action_update.resource_id == foo.id
      assert action_update.arguments == [foo]
      assert action_update.arguments_persisted == true
      assert action_update.result == {:ok, foo_deleted}
      assert action_update.result_persisted == true
    end
  end

  describe "actions are only logged for tracked oprations -" do
    test "accessing a foo doesn't log an action" do
      # Create a foo
      {:ok, %Foo{} = foo} = FBWD.create_foo(%{foo_x: "X1", foo_y: 1, foo_z: 1.0})
      %Foo{} = FBWD.get_foo!(foo.id)

      # There is only one action (the `:create_foo` action)
      [action] = FooBarRepo.all(HerodotusAction)

      # The action is a `:create_foo` action
      assert action.module == FBWD
      assert action.function == :create_foo
      assert action.arity == 1
      # Redundant
      assert action.function != :get_foo!
    end
  end
end
