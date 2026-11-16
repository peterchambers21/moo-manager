defmodule Cattle.DataCase do
  @moduledoc """
  Test case for code that touches the database. Each test runs in a
  transaction that is rolled back afterwards.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Cattle.Repo
      import Cattle.DataCase
      import Cattle.Fixtures
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc "Checks out a sandboxed connection for the test process."
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Cattle.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc "Turns changeset errors into `%{field: [messages]}`."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc "Asserts a Decimal (or nil) equals the expected number."
  defmacro assert_decimal(actual, expected) do
    quote do
      actual = unquote(actual)
      expected = unquote(expected)

      assert actual != nil and Decimal.equal?(actual, expected),
             "expected #{inspect(expected)}, got #{inspect(actual)}"
    end
  end
end
