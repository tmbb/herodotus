defmodule Herodotus.Action do
  @moduledoc """
  A Herodotus action is an ecto schema meant to be persisted to a database.

  This module provides a `__using__/1` macro that automatically generates
  and `Action` that refers to the applications `User` schema
  (to make it easy to audit user behaviour).

  This macro generates an Ecto schema with the following fields:

    * `:id` - by default, a binary ID.

    * `:resource_schema` - the Ecto schema of the resource affected by this action.
      This might be `nil` in a number of cases, for example if the action didn't
      touch the database or if it has touched in a number of schemas.

    * `:resource_id` - the ID of the Ecto schema affected by this action.
      This might be `nil` in a number of cases, for example if the action didn't
      touch the database or if it has touched in a number of schemas.

    * `:module` - the module where the tracked function is defined (as an atom)

    * `:function` - the tracked function (as an atom)

    * `:arity` - the arity of the tracked function.
      This field could be computed from the `:function_arguments` field, but it's
      still useful ion two situations: 1) when querying the actions table and
      2) when you don't want to save the function arguments (to save space or for privacy reasons)

    * `:result` - the result value of the tracked function.

    * `:result_persisted` - whether the result was persisted or not.

    * `:arguments` - the arguments with which the action was called, as a list.

    * `:arguments_persisted` - whether the arguments were persisted or not.

    * `:timestamp` - timesamp of action execution

    * `:user` - relation to a foreign table represented by the `user_schema` module

  ### Why do I have to create a specific `HerodotusAction` schema for my application?

  Although `Herodotus` could provide a ready-made `Action` schema, it has no knowledge
  of your user schema.
  It's important to be able to link an action to an user for auditing purposes,
  especially in multi-user (web?) applications, and the easiest way to do it
  is by linking the action to a user.
  The only way to do it is to make the action aware of the User schema,
  and it can't be done without a reference to the User schema.

  ## Examples

      defmodule MyApp.HerodotusAction do
        use Herodotus.Action, user_schema: MyApp.Accounts.User
      end

  """

  defmacro __using__(opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    table_name = Keyword.get(opts, :table_name, "herodotus_actions")

    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id

      schema unquote(table_name) do
        field(:resource_schema, Herodotus.EctoAtomType)
        field(:resource_id, Herodotus.EctoTermType)
        field(:module, Herodotus.EctoAtomType)
        field(:function, Herodotus.EctoAtomType)
        field(:arity, :integer)
        field(:arguments, Herodotus.EctoTermType)
        field(:arguments_persisted, :boolean)
        field(:result, Herodotus.EctoTermType)
        field(:result_persisted, :boolean)
        field(:timestamp, :utc_datetime_usec)

        belongs_to(:user, unquote(user_schema), on_replace: :nilify)
      end

      @doc false
      def changeset(audit_log_entry, attrs) do
        audit_log_entry
        |> cast(attrs, [
          :resource_schema,
          :resource_id,
          :module,
          :function,
          :arity,
          :arguments,
          :arguments_persisted,
          :result,
          :result_persisted
        ])
        |> cast_assoc(:user)
      end
    end
  end
end
