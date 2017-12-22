defmodule Concentrate.StructHelpers do
  @moduledoc false

  @doc """
  Builds accessors for each struct field.

  ## Example

      defmodule Test do
        defstruct_accessors([:one, :two])
      end

      iex> Test.one(Test.new(one: 1))
      1
  """
  defmacro defstruct_accessors(fields) do
    [
      define_struct(fields),
      define_new(),
      define_update()
    ] ++ for field <- fields, do: define_accessor(field)
  end

  @doc false
  def define_struct(fields) do
    quote do
      defstruct unquote(fields)
      @opaque t :: %__MODULE__{}
    end
  end

  @doc false
  def define_new do
    quote do
      @spec new(Keyword.t()) :: t
      def new(opts) when is_list(opts) do
        struct!(__MODULE__, opts)
      end

      defoverridable new: 1
    end
  end

  @doc false
  def define_update do
    quote do
      @spec update(%__MODULE__{}, Enumerable.t()) :: t
      def update(%__MODULE__{} = existing, opts) do
        Map.merge(existing, Map.new(opts))
      end
    end
  end

  @doc false
  def define_accessor({field, _default}) do
    define_accessor(field)
  end

  def define_accessor(field) do
    quote do
      @doc false
      @spec unquote(field)(%__MODULE__{}) :: any
      def unquote(field)(%__MODULE__{} = struct), do: Map.get(struct, unquote(field))
      defoverridable [{unquote(field), 1}]
    end
  end
end
