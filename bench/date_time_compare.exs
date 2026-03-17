smaller = DateTime.from_unix!(1_234_567)
bigger = DateTime.from_unix!(1_234_568)
much_bigger = DateTime.from_unix!(9_867_543)

inputs = %{
  "close": {smaller, bigger},
  "close reversed": {bigger, smaller},
  "far": {smaller, much_bigger},
  "far reversed": {much_bigger, smaller}
}
Benchee.run(
  %{
    "enum": fn {smaller, bigger} -> Enum.min_by([smaller, bigger], &DateTime.to_unix/1) end,
    "apply": fn {smaller, bigger} -> apply(Enum, :min_by, [[smaller, bigger], &DateTime.to_unix/1]) end,
    "compare": fn {smaller, bigger} -> if DateTime.compare(smaller, bigger) == :lt, do: smaller, else: bigger end
  },
  time: 5,
  inputs: inputs,
  print: [fast_warning: false]
)
