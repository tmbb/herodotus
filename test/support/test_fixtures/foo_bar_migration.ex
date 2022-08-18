defmodule HerodotusTest.TestFixtures.FooBarMigration do
  use Ecto.Migration

  def change do
    create table("foos") do
      add :foo_x, :string
      add :foo_y, :integer
      add :foo_z, :float
    end

    create table("bars") do
      add :bar_x, :string
      add :bar_y, :integer
      add :bar_z, :float
    end
  end
end
