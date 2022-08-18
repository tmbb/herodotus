defmodule HerodotusTest.TrackedPropertyTest do
  use ExUnit.Case

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

  require Ecto.Query, as: Query

  alias HerodotusTest.TestFixtures.FooTrackedArgumentCombinations, as: FTAC

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

  test "persist arguments, persist_result" do
    # Perform a "raw" insert, without logging an action
    {:ok, foo} = FooBarRepo.insert(%Foo{foo_x: "1", foo_y: 1, foo_z: 1.0})
    {:ok, test_user} = FooBarRepo.insert(
      %User{nickname: "tester", email: "tester@example.com", password: "PWD"}
    )

    for result_type <- [:schema, :changeset, :nothing] do
      for container_type <- [:ok_tuple, :error_tuple, :raw] do
        # Now, perform a tracked operations (thus logging an action into the repo)
        result =
          Herodotus.with_herodotus_user_id(test_user.id, fn ->
            FTAC.f__persist_arguments__persist_result(
              foo,
              %{foo_x: "2"},
              result_type,
              container_type
            )
          end)

        # Extract the single action we've created
        [action] = FooBarRepo.all(HerodotusAction)

        expected_arguments = [foo, %{foo_x: "2"}, result_type, container_type]
        expected_result = result

        assert action.module == FTAC
        assert action.function == :f__persist_arguments__persist_result
        assert action.arity == 4
        assert action.resource_schema == Foo
        assert action.resource_id == foo.id
        assert action.arguments == expected_arguments
        assert action.arguments_persisted == true
        assert action.result == expected_result
        assert action.result_persisted == true

        # Delete the action so that we can test another combination of arguments
        FooBarRepo.delete_all(Query.from HerodotusAction)
      end
    end
  end

  test "persist arguments, don't persist_result" do
    # Perform a "raw" insert, without logging an action
    {:ok, foo} = FooBarRepo.insert(%Foo{foo_x: "1", foo_y: 1, foo_z: 1.0})
    {:ok, test_user} = FooBarRepo.insert(
      %User{nickname: "tester", email: "tester@example.com", password: "PWD"}
    )

    for result_type <- [:schema, :changeset, :nothing] do
      for container_type <- [:ok_tuple, :error_tuple, :raw] do
        # Now, perform a tracked operations (thus logging an action into the repo)
        _result =
          Herodotus.with_herodotus_user_id(test_user.id, fn ->
            FTAC.f__persist_arguments__dont_persist_result(
              foo,
              %{foo_x: "2"},
              result_type,
              container_type
            )
          end)


        # Extract the single action we've created
        [action] = FooBarRepo.all(HerodotusAction)

        expected_arguments = [foo, %{foo_x: "2"}, result_type, container_type]

        assert action.module == FTAC
        assert action.function == :f__persist_arguments__dont_persist_result
        assert action.arity == 4
        assert action.resource_schema == Foo
        assert action.resource_id == foo.id
        assert action.arguments == expected_arguments
        assert action.arguments_persisted == true
        assert action.result == nil
        assert action.result_persisted == false

        # Delete the action so that we can test another combination of arguments
        FooBarRepo.delete_all(Query.from HerodotusAction)
      end
    end
  end

  test "don't persist arguments, persist_result" do
    # Perform a "raw" insert, without logging an action
    {:ok, foo} = FooBarRepo.insert(%Foo{foo_x: "1", foo_y: 1, foo_z: 1.0})
    {:ok, test_user} = FooBarRepo.insert(
      %User{nickname: "tester", email: "tester@example.com", password: "PWD"}
    )

    for result_type <- [:schema, :changeset, :nothing] do
      for container_type <- [:ok_tuple, :error_tuple, :raw] do
        # Now, perform a tracked operations (thus logging an action into the repo)
        result =
          Herodotus.with_herodotus_user_id(test_user.id, fn ->
            FTAC.f__dont_persist_arguments__persist_result(
              foo,
              %{foo_x: "2"},
              result_type,
              container_type
            )
          end)

        # Extract the single action we've created
        [action] = FooBarRepo.all(HerodotusAction)

        expected_result = result

        assert action.module == FTAC
        assert action.function == :f__dont_persist_arguments__persist_result
        assert action.arity == 4
        assert action.resource_schema == Foo
        assert action.resource_id == foo.id
        assert action.arguments == []
        assert action.arguments_persisted == false
        assert action.result == expected_result
        assert action.result_persisted == true

        # Delete the action so that we can test another combination of arguments
        FooBarRepo.delete_all(Query.from HerodotusAction)
      end
    end
  end

  test "don't persist arguments, don't persist_result" do
    # Perform a "raw" insert, without logging an action
    {:ok, foo} = FooBarRepo.insert(%Foo{foo_x: "1", foo_y: 1, foo_z: 1.0})
    {:ok, test_user} = FooBarRepo.insert(
      %User{nickname: "tester", email: "tester@example.com", password: "PWD"}
    )

    for result_type <- [:schema, :changeset, :nothing] do
      for container_type <- [:ok_tuple, :error_tuple, :raw] do
        # Now, perform a tracked operations (thus logging an action into the repo)
        _result =
          Herodotus.with_herodotus_user_id(test_user.id, fn ->
            FTAC.f__dont_persist_arguments__dont_persist_result(
              foo,
              %{foo_x: "2"},
              result_type,
              container_type
            )
          end)

        # Extract the single action we've created
        [action] = FooBarRepo.all(HerodotusAction)

        assert action.module == FTAC
        assert action.function == :f__dont_persist_arguments__dont_persist_result
        assert action.arity == 4
        assert action.resource_schema == Foo
        assert action.resource_id == foo.id
        assert action.arguments == []
        assert action.arguments_persisted == false
        assert action.result == nil
        assert action.result_persisted == false
        assert action.user_id == test_user.id

        # Delete the action so that we can test another combination of arguments
        FooBarRepo.delete_all(Query.from HerodotusAction)
      end
    end
  end
end
