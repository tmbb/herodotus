defmodule Herodotus do
  @moduledoc """

  """

  alias Herodotus.Tracker

  defmacro __using__(opts) do
    herodotus_action_schema = Keyword.fetch!(opts, :action_schema)
    herodotus_repo = Keyword.fetch!(opts, :repo)

    quote do
      require Herodotus
      @herodotus_action_schema unquote(herodotus_action_schema)
      @herodotus_repo unquote(herodotus_repo)
    end
  end

  @doc """
  Logs an action with the given `opts` using the default repo and action schema.

  The `:module`, `:function` and `:arity` parameters are
  automatically extracted from the compilation environment.

  The `:arguments` and `:result` need to be passed explicitly.
  Returns an action, not the action result.
  """
  defmacro log_action(opts) do
    default_module = __CALLER__.module
    {default_function, default_arity} = __CALLER__.function

    quote do
      all_opts =
        unquote(opts)
        |> Keyword.put_new(:module, unquote(default_module))
        |> Keyword.put_new(:function, unquote(default_function))
        |> Keyword.put_new(:arity, unquote(default_arity))

      Herodotus.log_action(@herodotus_repo, @herodotus_action_schema, all_opts)
    end
  end

  @doc """
  Logs an action into the given `repo`, using the given `action_schema`.
  """
  def log_action(repo, action_schema, opts) do
    resource_schema = Keyword.get(opts, :resource_schema, nil)
    resource_id = Keyword.get(opts, :resource_id, nil)
    module = Keyword.fetch!(opts, :module)
    function = Keyword.fetch!(opts, :function)
    arguments = Keyword.get(opts, :arguments)
    arguments_persisted = Keyword.get(opts, :arguments_persisted)
    arity = Keyword.fetch!(opts, :arity)
    result = Keyword.fetch!(opts, :result)
    result_persisted = Keyword.fetch!(opts, :result_persisted)

    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())
    user_id = Keyword.get(opts, :user_id)

    # maybe_redacted_arguments = Enum.map(arguments, fn a -> redact_fields(a, redacted_fields) end)
    # maybe_redacted_result = redact_fields(result, redacted_fields)

    # Use the `Kernel.struct/2` special form because it's the easiest
    # way of building a structure from a dynamic atom (module) name.
    action =
      struct(action_schema, %{
        resource_schema: resource_schema,
        resource_id: resource_id,
        module: module,
        function: function,
        arity: arity,
        arguments: arguments,
        arguments_persisted: arguments_persisted,
        result: result,
        result_persisted: result_persisted,
        timestamp: timestamp,
        user_id: user_id
      })

    repo.insert!(action)
  end

  defmacro track(tracker_args \\ [], body) do
    Tracker.track(__CALLER__, tracker_args, body)
  end

  @doc """
  Get the `herodotus_user_id` for the current process (or `nil`).
  """
  def get_herodotus_user_id() do
    Process.get(:herodotus_user_id)
  end

  @doc """
  Put a `herodotus_user_id` in the current process.
  """
  def put_herodotus_user_id(value) do
    Process.put(:herodotus_user_id, value)
  end

  @doc """
  Deletes a `herodotus_user_id` from the current process.
  """
  def delete_herodotus_user_id() do
    Process.delete(:herodotus_user_id)
  end

  @doc """
  Runs a given function with a `herodotus_user_id` for the current process.
  The old `herodotus_user_id` is reset after executing the function.

  If the function raises an error, the old `herodotus_user_id` is reset
  before raising the error.
  """
  def with_herodotus_user_id(user_id, fun) do
    # Maybe there isn't an user id before the function
    # is executed, but in that case it will the same
    # as being nil, so that's not a problem
    old_user_id = get_herodotus_user_id()
    try do
      put_herodotus_user_id(user_id)
      fun.()
    after
      # Restore the process dictionary to what it was before
      put_herodotus_user_id(old_user_id)
    end
  end
end
