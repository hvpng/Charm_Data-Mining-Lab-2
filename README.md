# Charm_Data-Mining-Lab-2

Julia implementation of the **CHARM** algorithm for mining Frequent Closed
Itemsets (FCIs) using a vertical (tidset-based) data representation.

> **Reference:** Zaki, M.J. & Hsiao, C.-J. (2002). *CHARM: An Efficient Algorithm
> for Closed Itemset Mining.* SIAM International Conference on Data Mining,
> pp. 457–473.

---

## Repository Structure

```
Charm/
├── Project.toml           # Julia project manifest
├── README.md
├── src/
│   ├── structures.jl      # Core data structures (Tidset, ItemsetNode, …)
│   ├── utils.jl           # I/O utilities (read_transactions, write_results, …)
│   └── algorithm/
│       └── charm.jl       # CHARM algorithm implementation
├── tests/
│   ├── test_correctness.jl
│   └── test_benchmark.jl
├── data/
│   ├── toy/               # Small example databases
│   └── benchmark/         # Synthetic benchmark databases
├── notebooks/
│   └── demo.ipynb         # Interactive Jupyter demo
└── docs/
    └── Report.md          # Algorithm documentation & report
```

---

## Quick Start

```julia
# From the Julia REPL (repo root):
include("src/algorithm/charm.jl")

txns = read_transactions("data/toy/example1.dat")
result = charm(txns, 3)         # min support count = 3
print_results(result)

# Or use a relative threshold:
result = charm(txns, 0.3)       # 30% of transactions
```

---

## Running Tests

```bash
# Correctness tests (unit + property-based)
julia --project=. tests/test_correctness.jl

# Benchmark / scalability tests
julia --project=. tests/test_benchmark.jl
```

---

## Algorithm Overview

CHARM explores the itemset lattice depth-first using four properties that prune
the search space based on tidset containment relationships:

| Property | Condition | Effect |
|----------|-----------|--------|
| 1 | T(Xi) ‖ T(Xj) | New child node (Xi∪Xj, T∩) |
| 2 | T(Xi) ⊆ T(Xj) | Extend Xi in place |
| 3 | T(Xi) ⊇ T(Xj) | New child; prune Xj |
| 4 | T(Xi) = T(Xj) | Extend Xi; prune Xj |

See [`docs/Report.md`](docs/Report.md) for full details.
