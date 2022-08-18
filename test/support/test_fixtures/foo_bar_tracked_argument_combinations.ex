defmodule HerodotusTest.TestFixtures.FooTrackedArgumentCombinations do
  import Ecto.Query, warn: false

  alias HerodotusTest.TestFixtures.Foo

  use Herodotus,
    action_schema: HerodotusTest.TestFixtures.HerodotusAction,
    repo: HerodotusTest.TestFixtures.FooBarRepo

  defp base_function(%Foo{} = foo, attrs, result_resource_type, result_container_type) do
    foo_changeset = Foo.changeset(foo, attrs)

    result =
      case result_resource_type do
        :changeset ->
          foo_changeset

        :schema ->
          foo

        :nothing ->
          nil
      end

    container =
      case result_container_type do
        :ok_tuple ->
          {:ok, result}

        :error_tuple ->
          {:error, result}

        :raw ->
          result
      end

    container
  end

  # Differently tracked versions of the base function

  Herodotus.track persist_arguments: true, persist_result: true do
    def f__persist_arguments__persist_result(foo, attrs, rt, ct) do
      base_function(foo, attrs, rt, ct)
    end
  end

  Herodotus.track persist_arguments: true, persist_result: false do
    def f__persist_arguments__dont_persist_result(foo, attrs, rt, ct) do
      base_function(foo, attrs, rt, ct)
    end
  end

  Herodotus.track persist_arguments: false, persist_result: true do
    def f__dont_persist_arguments__persist_result(foo, attrs, rt, ct) do
      base_function(foo, attrs, rt, ct)
    end
  end

  Herodotus.track persist_arguments: false, persist_result: false do
    def f__dont_persist_arguments__dont_persist_result(foo, attrs, rt, ct) do
      base_function(foo, attrs, rt, ct)
    end
  end
end
