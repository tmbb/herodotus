defmodule Herodotus.Tracker do
  @moduledoc false

  # This module is not meant to be exposed to users.
  # It contains the functions that do the actual work of rewriting
  # the AST of the functions we want to track.

  require Logger
  alias Ecto.Changeset

  @doc """
  Adds tracking to a number of function definitions encolosed by a `do ... end` block.

  This function takes the followin arguments:

    * `env` - an instance of `__CALLER__.env` supplied by the caller macro.
      Because `track/2` is a function and not a macro, it doesn't have access
      to the `__CALLER__` macro.

    * `tracker_args` - a keyword list of arguments that change the behaviour
      of the tracker

    * `tracked` - a `do ... end` block with one or more function definitions
      to which we want to add tracking,

  Returns a quoted expression with the modified function definitions.

  Expressions that are not function definitions are returned as they are.
  This allows you to enclose several function definitions with docstrings
  in `Herodotus.track do ... end` without problems (only the function AST will be re-written).
  """
  def track(env, tracker_args, [do: body] = tracked) do
    # If not given explicitly, the `repo` will be extracted from the `@herodotus_repo`
    # module attribute.
    # This attribute is automatically set by the `use Herodotus, ...` macro.
    repo = Keyword.get(tracker_args, :repo, quote(do: @herodotus_repo))
    # If not given explicitly, the `action_schema` will be extracted from the
    # `@herodotus_action_schema` module attribute.
    # This attribute is automatically set by the `use Herodotus, ...` macro.
    action_schema = Keyword.get(tracker_args, :action_schema, quote(do: @herodotus_action_schema))

    persist_arguments = Keyword.get(tracker_args, :persist_arguments, true)
    persist_result = Keyword.get(tracker_args, :persist_result, true)


    # The `:debug` options controls whether to show the code of the tracked functions
    # (after AST rewriting) at compilation time
    debug_tracker = Keyword.get(tracker_args, :debug, false)
    # The `:persist_decorated_source` options controls whether to show the code of the tracked functions
    # (after AST rewriting) at compilation time
    persist_decorated_source = Keyword.get(tracker_args, :persist_decorated_source, false)

    # Get a list of expressions enclosed by the `track do ... end` block.
    # There are two cases:
    expressions =
      case body do
        # There is a block with multiple expressions
        {:__block__, _meta, stmts} -> stmts
        # * There is a single expression
        other -> [other]
      end

    new_expressions =
      for expression <- expressions do
        add_tracking_if_definition(repo, action_schema, persist_arguments, persist_result, expression)
      end

    # Aggregate all expressions in a block (even if there is only a single expression)
    result = {:__block__, [], new_expressions}

    if debug_tracker do
      log_generated_code(env, result)
    end

    # Return the block we've created earlier
    result
  end

  defp generated_code(quoted) do
    quoted
    |> Macro.to_string()
    |> Code.format_string!()
    |> to_string()
  end

  defp log_generated_code(env, quoted) do
    # Get the text representation of the AST as a list of lines
    lines = String.split(generated_code(quoted), "\n")

    # Merge the lines into a text block, indenting each line by 4 spaces
    # (indented code looks better in the console, and helps separate different code blocks)
    indented_code =
      lines
      |> Enum.map(fn line -> ["    ", line] end)
      |> Enum.intersperse("\n")

    path = Path.relative_to_cwd(env.file)

    log_header = "Herodotus.track/2 - #{path}:#{env.line}"
    extra_padding = byte_size("[debug] ")
    underline_width = String.length(log_header) + extra_padding
    underline = String.duplicate("\u2500", underline_width)

    log_output = [log_header, "\n", underline, "\n\n", indented_code, "\n"]

    Logger.debug(log_output)
  end

  @doc """
  Adds tracking to an expression if and only if it is a function definition.
  Expressions that aren't function definitions will be returned unchanged.
  """
  def add_tracking_if_definition(repo, action_schema, persist_arguments, persist_result, expression) do
    # We will split the function definitions in 4 cases,
    # depending on whether the function definition:
    #
    #   * has guards (`def f(...), when ... do ... end`)
    #   * has zero or more arguments
    #
    # Functions with zero arguments are treated specially because we will
    # attempt to use the first argument and the return value of the function
    # to try to extract an Ecto schema and an Ecto schema ID to add extra
    # structured metadata to our action.
    #
    # Adding these fields to the database allows us to query actions based
    # on Ecto schemas and ecto schema IDs.
    #
    # If the function doesn't take any arguments, we will try to use the
    # return value of the function to extract the data above.
    case expression do
      # Function call with guards (`def f(x) when ... do ... end`):
      {:def, _meta1, [{:when, _meta2, [call, guards]}, [do: function_body]]} ->
        case Macro.decompose_call(call) do
          # This function doesn't take any arguments (dispatch appropriately)
          {f, []} ->
            tracked_definition_guards_no_arguments(
              repo, action_schema, persist_arguments, persist_result, {f, guards, [], function_body}
            )

          # This function takes at least one argument (dispatch appropriately)
          {f, args} when is_list(args) ->
            tracked_definition_no_guards_at_least_one_argument(
              repo, action_schema, persist_arguments, persist_result, {f, guards, args, function_body}
            )
        end

      # Function call without guards (`def f(x) do ... end`):
      {:def, _meta, [call, [do: function_body]]} ->
        case Macro.decompose_call(call) do
          # This function doesn't take any arguments (dispatch appropriately)
          {f, []} ->
            tracked_definition_no_guards_no_arguments(
              repo, action_schema, persist_arguments, persist_result, {f, [], function_body}
            )

          # This function takes at least one argument (dispatch appropriately)
          {f, args} when is_list(args) ->
            tracked_definition_no_guards_at_least_one_argument(
              repo, action_schema, persist_arguments, persist_result, {f, args, function_body}
            )
        end

      # Everything else is returned as it is;
      # This allows a `Herodotus.track do ... end` to span multiple calls
      # including things such as documentation comments and module attributes.
      other ->
        other
    end
  end

  def tracked_definition_no_guards_no_arguments(
        repo,
        action_schema,
        persist_arguments,
        persist_result,
        {f, [], function_body}
      ) do

    quote do
      def unquote(f)() do
        # Actually exectute the original code and save the results
        result = unquote(function_body)

        persist_arguments = unquote(persist_arguments)
        persist_result = unquote(persist_result)

        # Log the action:
        # ---------------

        # Try to extract the resource schema using heuristics
        resource_schema = Herodotus.Tracker.get_schema_module(result)

        # Try to extract the resource id using heuristics
        resource_id = Herodotus.Tracker.get_resource_id(result)

        Herodotus.log_action(unquote(repo), unquote(action_schema),
          resource_schema: resource_schema,
          resource_id: resource_id,
          module: __MODULE__,
          function: unquote(f),
          arity: 0,
          arguments: [],
          arguments_persisted: persist_arguments,
          result: (if persist_result, do: result, else: nil),
          result_persisted: true,
          user_id: Herodotus.get_herodotus_user_id()
        )

        # Return the original result  (the action is logged as a side-effect)
        result
      end
    end
  end

  def tracked_definition_no_guards_at_least_one_argument(
        repo,
        action_schema,
        persist_arguments,
        persist_result,
        {f, args, function_body}
      ) do

    arity = length(args)
    cleaned_args = clean_double_backslashes(args)
    [first_argument | _rest] = cleaned_args

    quote do
      def unquote(f)(unquote_splicing(args)) do
        # Actually exectute the original code and save the results
        result = unquote(function_body)

        persist_arguments = unquote(persist_arguments)
        persist_result = unquote(persist_result)

        # Log the action:
        # ---------------

        # Try to extract the resource schema using heuristics
        resource_schema =
          Herodotus.Tracker.get_schema_module_from_values([
            unquote(first_argument),
            result
          ])

        # Try to extract the resource id using heuristics
        resource_id =
          Herodotus.Tracker.get_resource_id_from_values([
            unquote(first_argument),
            result
          ])

        Herodotus.log_action(unquote(repo), unquote(action_schema),
          resource_schema: resource_schema,
          resource_id: resource_id,
          module: __MODULE__,
          function: unquote(f),
          arity: unquote(arity),
          arguments: (if persist_arguments, do: unquote(cleaned_args), else: []),
          arguments_persisted: persist_arguments,
          result: (if persist_result, do: result, else: nil),
          result_persisted: persist_result,
          user_id: Herodotus.get_herodotus_user_id()
        )

        # Return the original result (the action is logged as a side-effect)
        result
      end
    end
  end

  def tracked_definition_guards_no_arguments(
        repo,
        action_schema,
        persist_arguments,
        persist_result,
        {f, guards, [], function_body}
      ) do

    quote do
      def unquote(f)() when unquote(guards) do
        # Actually exectute the original code and save the results
        result = unquote(function_body)

        persist_arguments = unquote(persist_arguments)
        persist_result = unquote(persist_result)

        # Log the action:
        # ---------------

        # Try to extract the resource schema using heuristics
        resource_schema = Herodotus.Tracker.get_schema_module(result)

        # Try to extract the resource id using heuristics
        resource_id = Herodotus.Tracker.get_resource_id(result)

        Herodotus.log_action(unquote(repo), unquote(action_schema),
          resource_schema: resource_schema,
          resource_id: resource_id,
          module: __MODULE__,
          function: unquote(f),
          arity: 0,
          arguments: [],
          arguments_persisted: persist_arguments,
          result: (if persist_result, do: result, else: nil),
          result_persisted: persist_result,
          user_id: Herodotus.get_herodotus_user_id()
        )

        # Return the original result  (the action is logged as a side-effect)
        result
      end
    end
  end

  def tracked_definition_guards_at_least_one_argument(
        repo,
        action_schema,
        persist_arguments,
        persist_result,
        {f, guards, args, function_body}
      ) do

    arity = length(args)
    cleaned_args = clean_double_backslashes(args)
    [first_argument | _rest] = cleaned_args


    quote do
      def unquote(f)(unquote_splicing(args)) when unquote(guards) do
        # Actually exectute the original code and save the results
        result = unquote(function_body)

        persist_arguments = unquote(persist_arguments)
        persist_result = unquote(persist_result)

        # Log the action:
        # ---------------

        # Try to extract the resource schema using heuristics
        resource_schema =
          Herodotus.Tracker.get_schema_module_from_values([
            unquote(first_argument),
            result
          ])

        # Try to extract the resource id using heuristics
        resource_id =
          Herodotus.Tracker.get_resource_id_from_values([
            unquote(first_argument),
            result
          ])

        Herodotus.log_action(unquote(repo), unquote(action_schema),
          resource_schema: resource_schema,
          resource_id: resource_id,
          module: __MODULE__,
          function: unquote(f),
          arity: unquote(arity),
          arguments: (if persist_arguments, do: unquote(cleaned_args), else: []),
          arguments_persisted: persist_arguments,
          result: (if persist_result, do: result, else: nil),
          result_persisted: true,
          user_id: Herodotus.get_herodotus_user_id()
        )

        # Return the original result and not the action
        # (the action is logged as a side-effect)
        result
      end
    end
  end

  @doc false
  # def redact_fields(struct_or_chanegset_or_something_else) do
  #   case strruct_or_changeset_ot_something_else do

  #   end
  # end

  @doc false
  def get_schema_module(struct_or_changeset_or_something_else) do
    case struct_or_changeset_or_something_else do
      changeset = %Changeset{} ->
        %schema{} = changeset.data
        schema

      %schema{} ->
        schema

      {:ok, value} ->
        get_schema_module(value)

      {:error, value} ->
        get_schema_module(value)

      _ ->
        nil
    end
  end

  @doc false
  def get_resource_id(struct_or_changeset_or_something_else) do
    case struct_or_changeset_or_something_else do
      %_schema{} = struct ->
        struct.id

      {:ok, value} ->
        get_resource_id(value)

      {:error, value} ->
        get_resource_id(value)

      changeset = %Changeset{} ->
        changeset.data.id

      _ ->
        nil
    end
  end

  @doc false
  def get_schema_module_from_values([]) do
    nil
  end

  def get_schema_module_from_values([value | values]) do
    case get_schema_module(value) do
      nil ->
        get_schema_module_from_values(values)

      schema ->
        schema
    end
  end

  @doc false
  def get_resource_id_from_values([]) do
    nil
  end

  @doc false
  def get_resource_id_from_values([value | values]) do
    case get_resource_id(value) do
      nil ->
        get_resource_id_from_values(values)

      resource_id ->
        resource_id
    end
  end

  def clean_double_backslashes(quoted_args) do
    # Function arguments in Elixir can usually be spliced into
    # "normal code", with one exaception.
    # Optional arguments (written as `arg \\ optional_value`).
    # The AST for this is `{:\\, _meta, [left, right]}`.
    # If we take the left side of the value in these expressions,
    # we get a valid list of quoted expressions which can be inserted
    # anywhere in the function body.
    for quoted_arg <- quoted_args do
      case quoted_arg do
        {:\\, _, [left, _right]} ->
          left

        other ->
          other
      end
    end
  end
end
