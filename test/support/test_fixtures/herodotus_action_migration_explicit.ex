defmodule HerodotusTest.TestFixtures.HerodotusActionMigrationExplicit do
  use Ecto.Migration
  require Herodotus.Migration

  def change() do
    Herodotus.Migration.change(users_table: :users)
  end
end
