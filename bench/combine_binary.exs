defmodule CombineBinary do
  def binary_join(blocks) do
    Enum.reduce(blocks, "", fn block, acc -> acc <> block end)
  end

  # def iolist([block]) do
  #   block
  # end

  def iolist(blocks) do
    blocks
    |> Enum.reduce([], fn block, acc -> [acc, block] end)
    |> IO.iodata_to_binary
  end

  def reverse_join(blocks) do
    blocks
    |> Enum.reverse
    |> Enum.join("")
  end
end

block = String.duplicate("block", 100)
inputs = %{
  "1" => [:binary.copy(block)],
  "10" => for(_i <- 0..10, do: :binary.copy(block)),
  "100" => for(_i <- 0..100, do: :binary.copy(block))
}

Benchee.run(%{
      #"reverse_join": &CombineBinary.reverse_join/1,
      "binary_join": &CombineBinary.binary_join/1,
      "iolist": &CombineBinary.iolist/1,
            },
  inputs: inputs,
  print: [fast_warning: false]
)
