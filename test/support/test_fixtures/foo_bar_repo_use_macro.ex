defmodule HerodotusTest.TestFixtures.FooBarRepoUseMacro do
  use Ecto.Repo,
    otp_app: :herodotus_test,
    adapter: Ecto.Adapters.SQLite3
end
