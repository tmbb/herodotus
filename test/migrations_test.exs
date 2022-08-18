defmodule HerodotusTest.MigrationsTest do
  use ExUnit.Case
  doctest Herodotus

  alias HerodotusTest.Setup

  alias HerodotusTest.TestFixtures.{
    FooBarRepoUseMacro,
    FooBarRepoExplicit,
    UserMigration,
    HerodotusActionMigration,
    HerodotusActionMigrationExplicit,
  }

  test "two ways of running the migration are equivalent" do
    migrations_use_macro = [
      UserMigration,
      HerodotusActionMigration
    ]

    migrations_explicit = [
      UserMigration,
      HerodotusActionMigrationExplicit
    ]

    Setup.setup_test_database(
      Ecto.Adapters.SQLite3,
      FooBarRepoUseMacro,
      migrations_use_macro
    )

    Setup.setup_test_database(
      Ecto.Adapters.SQLite3,
      FooBarRepoExplicit,
      migrations_explicit
    )


    # Query the schemas of the two databases and compare them:
    # (the following code is obviously SQLite-specific)
    sql_full_schema = "SELECT s.sql FROM sqlite_schema AS s"
    schema_use_macro = FooBarRepoUseMacro.query!(sql_full_schema)
    schema_explicit = FooBarRepoExplicit.query!(sql_full_schema)
    # Assert that the schema is equal
    assert schema_use_macro == schema_explicit

    # Query the definition of the `herodotus_actions` table
    sql_actions_table = """
      SELECT s.sql
        FROM sqlite_schema AS s
        WHERE s.type = 'table' AND
              s.name = 'herodotus_actions'
      """

    expected_create_statement = """
    CREATE TABLE herodotus_actions (
      id TEXT_UUID PRIMARY KEY,
      resource_schema TEXT,
      resource_id BLOB,
      module TEXT,
      function TEXT,
      arity INTEGER,
      arguments BLOB,
      arguments_persisted BOOLEAN,
      result BLOB,
      result_persisted BOOLEAN,
      timestamp TEXT_DATETIME,
      user_id INTEGER
        CONSTRAINT herodotus_actions_user_id_fkey REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
    )
    """

    create_table_use_macro =
      FooBarRepoUseMacro.query!(sql_actions_table)
      |> singleton_from_sqlite_result()

    create_table_explicit =
      FooBarRepoUseMacro.query!(sql_actions_table)
      |> singleton_from_sqlite_result()

    assert to_canonical_sql(create_table_use_macro) == to_canonical_sql(expected_create_statement)
    assert to_canonical_sql(create_table_explicit) == to_canonical_sql(expected_create_statement)
  end

  setup_all do
    on_exit(fn ->
      Setup.teardown_test_database(Ecto.Adapters.SQLite3, FooBarRepoUseMacro)
      Setup.teardown_test_database(Ecto.Adapters.SQLite3, FooBarRepoExplicit)
    end)
  end

  # Private helper functions
  defp to_canonical_sql(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s+\)/, ")")
    |> String.replace(~r/\(\s+/, "(")
    |> String.replace(~r/\"(\w+)\"/, fn x -> binary_part(x, 1, byte_size(x) - 2) end)
    |> String.trim()
  end

  defp singleton_from_sqlite_result(result) do
    # Use pattern matching to ensure the result actually contains a singleton value
    [[singleton]] = result.rows
    # Return that value
    singleton
  end
end
