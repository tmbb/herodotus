defmodule HerodotusTest.TestFixtures.UserMigration do
  use Ecto.Migration

  def change do
    create table("users", primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:nickname, :string)
      add(:email, :string)
      add(:password, :string)
    end
  end
end
