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

## Chapter 5 (Optional) - Practical Application Demo

This project includes a practical Market Basket Analysis demo on a real retail dataset,
using the team's own CHARM implementation (no external FIM mining library output).

### 1) Run Chapter 5 experiment

```bash
julia --project=. scripts/market_basket_rules.jl
```

Expected artifacts:

- `results/retail_top10_rules.csv` (top-10 association rules sorted by lift)

Expected console summary (example):

- number of transactions
- effective `minsup(abs)`
- `minconf`
- number of closed itemsets
- number of generated rules

### 2) Verify Chapter 5 results (for instructors)

Run independent verification of support/confidence/lift values in the top-10 CSV:

```bash
julia --project=. scripts/verify_top10_rules.jl
```

Expected output:

```text
Top10 verification: PASS
```

This verifier recomputes all metrics directly from `data/benchmark/retail.txt`
and checks equality with `results/retail_top10_rules.csv`.

### 3) Quick grading checklist

- Run command in step (1) without errors.
- Confirm file `results/retail_top10_rules.csv` is generated.
- Run command in step (2) and confirm `Top10 verification: PASS`.
- Open `docs/Report.md` section `3.5` for interpretation/business discussion.
