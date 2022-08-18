ExUnit.start()

foo_bar_path = Path.expand("./db/foo_bar.db", Path.dirname(__ENV__.file))
foo_bar_use_macro_path = Path.expand("./db/foo_bar_use_macro.db", Path.dirname(__ENV__.file))
foo_bar_explicit_path = Path.expand("./db/foo_bar_explicit.db", Path.dirname(__ENV__.file))

parameters = [
  {HerodotusTest.TestFixtures.FooBarRepo, foo_bar_path},
  {HerodotusTest.TestFixtures.FooBarRepoUseMacro, foo_bar_use_macro_path},
  {HerodotusTest.TestFixtures.FooBarRepoExplicit, foo_bar_explicit_path},
]

for {repo_module, path} <- parameters do
  Application.put_env(
    :herodotus_test,
    repo_module,
    adapter: Ecto.Adapters.SQLite3,
    database: path,
    pool: Ecto.Adapters.SQL.Sandbox
  )
end
