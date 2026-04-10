# Charm_Data-Mining-Lab-2

From-scratch Julia (>=1.9) implementation of tidset-based frequent itemset mining with:
- **All frequent itemsets** (`output_mode=:all`)
- **Closed frequent itemsets** (`output_mode=:closed`, CHARM-style property search)
- Two implementations:
  - `:basic` (Set tidsets)
  - `:bitset` (BitVector tidsets, optimized)

## Environment setup

### Requirements
- Julia **1.9+**
- No external FIM library is used

### Install dependencies

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## How to run

### Run from Julia REPL

```julia
include("src/algorithm/charm.jl")

txns = read_spmf_transactions("data/toy/toy1.txt")
result = charm(txns, 2; output_mode=:all, implementation=:bitset)
print_results(result)
write_spmf_itemsets(result, "results/toy1_out.txt")
```

### Run via CLI

```bash
julia --project=. src/cli.jl \
  --input data/toy/toy1.txt \
  --output results/toy1_cli_out.txt \
  --minsup 2 \
  --mode all \
  --impl bitset
```

Options:
- `--minsup`: absolute (e.g. `2`) or relative (e.g. `0.05`)
- `--mode`: `all` or `closed`
- `--impl`: `basic` or `bitset`

## Unit tests (automatic)

Run the full automated suite with:

```bash
julia --project=. test/runtests.jl
```

This runs correctness, benchmark, and I/O tests end-to-end.

## Reproducibility

- The evaluation script sets a fixed random seed before synthetic-data generation.
- Re-running `scripts/evaluate.jl` produces reproducible synthetic benchmark results.

## Evaluation workflow

Place benchmark files in `data/benchmark/` with names such as:
- `chess.txt`
- `mushroom.txt`
- `retail.txt`
- `accidents.txt`
- `T10I4D100K.txt`

Then run:

```bash
julia --project=. scripts/evaluate.jl
```

Generated CSV reports are written to `results/`.
