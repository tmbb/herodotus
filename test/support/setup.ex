defmodule HerodotusTest.Setup do
  @doc """
  Programmatically starts a database and runs the given migrations.

  Ecto should definitely make this easier...
  """
  def setup_test_database(adapter, repo, migrations, migration_options \\ [log: false]) do
    {:ok, _} = adapter.ensure_all_started(repo, :temporary)
    _ = adapter.storage_down(repo.config())
    :ok = adapter.storage_up(repo.config())
    {:ok, _pid} = repo.start_link()

    # Run all the migrations
    start_timestamp = 20220101000000
    for {migration, i} <- Enum.with_index(migrations) do
      timestamp = start_timestamp + i
      Ecto.Migrator.up(repo, timestamp, migration, migration_options)
    end
  end

  @doc """
  Tears down a database created for testing.
  """
  def teardown_test_database(adapter, repo) do
    _ = adapter.storage_down(repo.config())
  end
end
