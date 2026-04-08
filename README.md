# Charm_Data-Mining-Lab-2

From-scratch Julia (>=1.9) implementation of tidset-based frequent itemset mining with:
- **All frequent itemsets** (`output_mode=:all`)
- **Closed frequent itemsets** (`output_mode=:closed`)
- Two implementations for comparison:
  - `:basic` (Set tidsets)
  - `:bitset` (BitVector tidsets, optimized)

## Project structure

```
Project.toml
src/
  algorithm/charm.jl
  structures.jl
  utils.jl
  cli.jl
tests/
  test_correctness.jl
  test_benchmark.jl
data/
  toy/
  benchmark/
  reference/spmf/
scripts/
  evaluate.jl
results/
```

## SPMF input/output format

- Input: one transaction per line, space-separated integer items.
- Output: `item1 item2 ... #SUP: n`

## Run from Julia REPL

```julia
include("src/algorithm/charm.jl")

txns = read_spmf_transactions("data/toy/toy1.txt")
result = charm(txns, 2; output_mode=:all, implementation=:bitset)
print_results(result)
write_spmf_itemsets(result, "out.txt")
```

## CLI usage

```bash
julia --project=. src/cli.jl \
  --input data/toy/toy1.txt \
  --output results/toy1_out.txt \
  --minsup 2 \
  --mode all \
  --impl bitset
```

- `--minsup`: absolute (e.g. `2`) or relative (e.g. `0.05`)
- `--mode`: `all` or `closed`
- `--impl`: `basic` or `bitset`

## Tests

```bash
julia --project=. tests/test_correctness.jl
julia --project=. tests/test_benchmark.jl
```

- Correctness tests validate **5 datasets** against SPMF-format reference outputs.
- Benchmark tests compare runtime curves and memory between baseline and optimized versions.

## Evaluation workflow

Place benchmark files in `data/benchmark/` with names:
- `chess.txt`
- `mushroom.txt`
- `retail.txt`
- `accidents.txt`
- `T10I4D100K.txt`

Then run:

```bash
julia --project=. scripts/evaluate.jl
```

It produces CSVs in `results/` for:
- correctness ratio vs reference
- runtime vs minsup
- number of frequent itemsets vs minsup
- memory basic vs optimized
- scalability by DB size
- average transaction length impact
