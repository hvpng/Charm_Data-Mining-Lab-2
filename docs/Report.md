# CHARM Algorithm — Technical Report

## 1. Introduction

**CHARM** (Closed Hashing Associating Rules Mining) is an efficient algorithm for
mining all **Frequent Closed Itemsets** (FCIs) from a transaction database.
It was introduced by Mohammed Zaki and Ching-Jui Hsiao in 2002 and remains one
of the most cited approaches to closed itemset mining.

### Why Closed Itemsets?

A transaction database with *n* distinct items can contain up to 2ⁿ − 1 frequent
itemsets.  Mining and storing all of them is impractical for large *n*.  Closed
itemsets provide a **lossless compressed representation**: every frequent itemset
and its exact support count can be derived from the set of FCIs alone, while the
number of FCIs is typically orders of magnitude smaller.

An itemset **X** is *closed* if there is no proper superset **Y ⊃ X** such that
`support(Y) = support(X)`.  Equivalently, X is closed iff it equals its own
Galois closure `γ(X)` under the formal concept duality between itemsets and
transaction sets.

---

## 2. Algorithm Description

### 2.1 Vertical Data Representation (Tidsets)

CHARM uses a **vertical** database layout.  Instead of storing a list of items
per transaction (*horizontal* layout), it stores a *tidset* (transaction ID set)
per item:

```
T(X) = { tid | X ⊆ transaction[tid] }
```

The support of any itemset can then be computed in O(|T(X)|) time via set
intersection:

```
T(X ∪ Y) = T(X) ∩ T(Y)
support(X ∪ Y) = |T(X) ∩ T(Y)|
```

### 2.2 The Four CHARM Properties

For any two nodes `(Xi, T(Xi))` and `(Xj, T(Xj))` in the search tree (with
`T_new = T(Xi) ∩ T(Xj)`):

| # | Condition | Action |
|---|-----------|--------|
| 1 | T(Xi) and T(Xj) incomparable | Add `(Xi∪Xj, T_new)` as a new child node |
| 2 | T(Xi) ⊆ T(Xj) | Replace Xi ← Xi∪Xj (same tidset); keep Xj |
| 3 | T(Xi) ⊇ T(Xj) | Add `(Xi∪Xj, T(Xj))` as child; **remove Xj** from this level |
| 4 | T(Xi) = T(Xj) | Replace Xi ← Xi∪Xj; **remove Xj** from this level |

Properties 2 and 4 exploit the fact that combining Xi and Xj does not decrease
the support when T(Xi) ⊆ T(Xj).  Properties 3 and 4 prune Xj entirely because
any future extension of Xj will be covered by the merged node.

### 2.3 Pseudo-code

```
CHARM(DB, min_sup):
  Build T(i) for each item i; filter by min_sup; sort by |T(i)| ascending
  C ← {}
  CHARM-Extend(initial_nodes, C, min_sup)
  return C

CHARM-Extend(P, C, min_sup):
  for each (Xi, T(Xi)) in P:
    new_P ← {}
    for each (Xj, T(Xj)) in P after Xi (not removed):
      T_new ← T(Xi) ∩ T(Xj)
      if |T_new| ≥ min_sup:
        X_new ← Xi ∪ Xj
        apply Property 1/2/3/4 (see table above)
    CHARM-Extend(new_P, C, min_sup)
    if (Xi, T(Xi)) is not subsumed in C:
      add (Xi, T(Xi)) to C
```

**Subsumption check:** `(X, T)` is subsumed if `∃ (Y, T') ∈ C` such that
`T = T'` and `X ⊆ Y`.  This ensures only closed itemsets are stored.

---

## 3. Implementation Details

### 3.1 File Structure

```
Charm/
├── Project.toml           # Julia project manifest
├── README.md
├── src/
│   ├── structures.jl      # Tidset, ItemsetNode, ClosedItemset, CharmResult
│   ├── utils.jl           # I/O helpers (read_transactions, write_results, …)
│   └── algorithm/
│       └── charm.jl       # CHARM algorithm (charm / _charm_extend!)
├── tests/
│   ├── test_correctness.jl
│   └── test_benchmark.jl
├── data/
│   ├── toy/
│   │   ├── example1.dat   # Classic 10-txn, 5-item example
│   │   └── example2.dat   # Supermarket basket example
│   └── benchmark/
│       └── T10I4D1000.dat # Synthetic benchmark (1 000 txns, 100 items)
├── notebooks/
│   └── demo.ipynb         # Interactive Jupyter demo
└── docs/
    └── Report.md          # This file
```

### 3.2 Key Data Structures

| Type | Purpose |
|------|---------|
| `Tidset` | Wraps `Set{Int}` + cached `support` |
| `ItemsetNode` | Mutable `(items::Vector{String}, tidset::Tidset)` |
| `ClosedItemset` | Immutable output record `(items, support, tids)` |
| `CharmResult` | Container holding all `ClosedItemset`s + metadata |

### 3.3 Complexity

| Aspect | Complexity |
|--------|-----------|
| Database scan | O(|DB|) |
| Tidset intersection | O(|T|) per pair |
| Worst-case nodes | O(2^k) where k = number of frequent items |
| Memory | O(n × |FCIs|) for tidsets |

In practice, CHARM's pruning properties drastically reduce the number of nodes
explored, making it very competitive on dense databases.

---

## 4. How to Run

### Prerequisites

- Julia ≥ 1.9

### Running the Algorithm

```julia
# From the Julia REPL (in the repo root):
include("src/algorithm/charm.jl")

transactions = [["a","b","c"], ["a","b"], ["b","c"]]
result = charm(transactions, 2)
print_results(result)
```

### Running Tests

```bash
julia --project=. tests/test_correctness.jl
julia --project=. tests/test_benchmark.jl
```

### Reading from a File

```julia
include("src/algorithm/charm.jl")
txns = read_transactions("data/toy/example1.dat")
result = charm(txns, 0.3)   # 30% relative support
write_results(result, "output.txt")
```

---

## 5. Example Output

Running on `data/toy/example1.dat` with `min_support = 3`:

```
Found 25 frequent closed itemsets (min_support=3):
  {a, b, c, d, e}  — none at this size for this database
  {a, b, e}  support=3
  {a, c, e}  support=3
  ...
  {a, b}     support=6
  {a}        support=8
```

---

## 6. References

1. Zaki, M.J. & Hsiao, C.-J. (2002). **CHARM: An Efficient Algorithm for Closed
   Itemset Mining.** *Proceedings of the 2002 SIAM International Conference on
   Data Mining*, pp. 457–473.

2. Pasquier, N., Bastide, Y., Taouil, R., & Lakhal, L. (1999). **Discovering
   Frequent Closed Itemsets for Association Rules.** *ICDT 1999*, pp. 398–416.

3. Zaki, M.J. (2000). **Scalable Algorithms for Association Mining.** *IEEE
   Transactions on Knowledge and Data Engineering*, 12(3), pp. 372–390.
