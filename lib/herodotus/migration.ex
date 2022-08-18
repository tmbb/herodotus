defmodule Herodotus.Migration do
  @moduledoc """
  Utilities to generate the necessary migrations to add Herodotus actions
  to your database.

  You probably want to start with `use Herodotus.Migration` and maybe later customize
  the migration module with additional indices.
  """


  @doc """
  Generate an entire migration module with minimal code

  Options:

    * `users_table` - an atom representing the name of the users table.
      The default value is `:users`.

  ## Example

      defmodule MyApp.HerodotusActionMigration do
        use Herodotus.Migration, users_table: :users
      end
  """
  defmacro __using__(opts \\ []) do
    users_table = Keyword.get(opts, :users_table, :users)

    quote do
      # This is meant to create a full migration module
      # It must `use Ecto.Migration` and define a `change/1` function
      use Ecto.Migration
      # Now, after using Ecto.Migration, we can dump the rest of the code
      def change() do
        unquote(herodotus_change(users_table))
      end
    end
  end

  @doc """
  Macro to create the correct table and indices.any()

  ## Example

      defmodule MyApp.HerodotusActionMigration do
        use Ecto.Migration
        require Herodotus.Migration

        def change() do
          Herodotus.Migration.change(users_table: :users)
        end
      end
  """
  defmacro change(opts \\ []) do
    users_table = Keyword.get(opts, :users_table, :users)
    herodotus_change(users_table)
  end

  defp herodotus_change(users_table) do
    quote do
      create table(:herodotus_actions, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:resource_schema, :string)
        add(:resource_id, :binary)
        add(:module, :string)
        add(:function, :string)
        add(:arity, :integer)
        add(:arguments, :binary)
        add(:arguments_persisted, :boolean)
        add(:result, :binary)
        add(:result_persisted, :boolean)
        add(:timestamp, :utc_datetime_usec)
        add(
          :user_id,
          references(
            unquote(users_table),
            on_update: :update_all,
            on_delete: :nilify_all
          )
        )
      end

      create(index(:herodotus_actions, [:user_id]))
      create(index(:herodotus_actions, [:timestamp]))

      create(
        index(:herodotus_actions, [
          :module,
          :function
        ])
      )
    end
  end
end
