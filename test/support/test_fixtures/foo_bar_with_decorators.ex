defmodule HerodotusTest.TestFixtures.FooBarWithDecorators do
  import Ecto.Query, warn: false

  alias HerodotusTest.TestFixtures.{
    FooBarRepo,
    Foo
  }

  use Herodotus,
    action_schema: HerodotusTest.TestFixtures.HerodotusAction,
    repo: HerodotusTest.TestFixtures.FooBarRepo

  @doc """
  Gets a foo from the database.
  """
  def get_foo!(id) do
    FooBarRepo.get!(Foo, id)
  end

  # A `Herodotus.track do ... end` block can include several functions.
  Herodotus.track do
    @doc """
    Creates a foo. Docstrings can be included in a `Herodotus.track do ... end` block.
    """
    def create_foo(attrs \\ %{}) do
      %Foo{}
      |> Foo.changeset(attrs)
      |> FooBarRepo.insert()
    end

    @doc """
    Updates a foo.
    Here is another docstring.
    """
    def update_foo(%Foo{} = foo, attrs) do
      foo
      |> Foo.changeset(attrs)
      |> FooBarRepo.update()
    end
  end

  Herodotus.track do
    @doc """
    Deletes a foo.
    """
    def delete_foo(%Foo{} = foo) do
      FooBarRepo.delete(foo)
    end
  end

  def change_foos(%Foo{} = foo) do
    Foo.changeset(foo, %{})
  end
end
