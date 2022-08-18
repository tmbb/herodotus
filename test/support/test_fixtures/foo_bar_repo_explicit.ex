defmodule HerodotusTest.TestFixtures.FooBarRepoExplicit do
  use Ecto.Repo,
    otp_app: :herodotus_test,
    adapter: Ecto.Adapters.SQLite3
end
