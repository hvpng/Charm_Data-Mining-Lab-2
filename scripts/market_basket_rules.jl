"""
Chuong 5 (Optional) - Ung dung thuc te: Market Basket Analysis

Yeu cau:
- Dung chinh cai dat CHARM cua nhom de lay frequent itemsets
- Sinh association rules voi sup >= minsup va conf >= minconf
- Xuat top-10 rule theo lift

Cach chay:
  julia --project=. scripts/market_basket_rules.jl

Tham so co the sua nhanh trong MAIN_CONFIG.
"""

include(joinpath(@__DIR__, "..", "src", "algorithm", "charm.jl"))

struct AssocRule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    support_count::Int
    support::Float64
    confidence::Float64
    lift::Float64
end

struct EncodedDataset
    transactions::Vector{Vector{Int}}
    id_to_token::Dict{Int, String}
end

const ROOT = normpath(joinpath(@__DIR__, ".."))
const MAIN_CONFIG = (
    input_path = joinpath(ROOT, "data", "benchmark", "retail.txt"),
    output_csv = joinpath(ROOT, "results", "retail_top10_rules.csv"),
    minsup = 0.02,      # relative minsup
    minconf = 0.35,
    impl = :bitset,
    topk = 10,
)

function combinations_indices(n::Int, k::Int)
    k <= 0 && return Vector{Vector{Int}}()
    k > n && return Vector{Vector{Int}}()

    result = Vector{Vector{Int}}()
    comb = collect(1:k)
    while true
        push!(result, copy(comb))

        i = k
        while i >= 1 && comb[i] == n - k + i
            i -= 1
        end
        i == 0 && break

        comb[i] += 1
        for j in (i + 1):k
            comb[j] = comb[j - 1] + 1
        end
    end
    return result
end

function read_transactions_encoded(filepath::String)::EncodedDataset
    token_to_id = Dict{String, Int}()
    id_to_token = Dict{Int, String}()
    txns = Vector{Vector{Int}}()

    open(filepath, "r") do f
        for line in eachline(f)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "#") && continue

            ids = Int[]
            for token in split(s)
                id = get!(token_to_id, token) do
                    new_id = length(token_to_id) + 1
                    id_to_token[new_id] = token
                    new_id
                end
                push!(ids, id)
            end
            push!(txns, sort!(unique(ids)))
        end
    end

    return EncodedDataset(txns, id_to_token)
end

function proper_subsets(items::Vector{Int})
    n = length(items)
    out = Vector{Vector{Int}}()
    for k in 1:(n - 1)
        for idxs in combinations_indices(n, k)
            push!(out, items[idxs])
        end
    end
    return out
end

function support_count(items::Vector{Int}, txns::Vector{Set{Int}}, cache::Dict{Tuple{Vararg{Int}}, Int})
    key = Tuple(items)
    if haskey(cache, key)
        return cache[key]
    end

    target = Set(items)
    cnt = 0
    for txn in txns
        issubset(target, txn) && (cnt += 1)
    end
    cache[key] = cnt
    return cnt
end

function mine_rules_from_closed_itemsets(transactions::Vector{Vector{Int}}, minsup::Real, minconf::Float64; implementation::Symbol=:bitset)
    result = charm(transactions, minsup; implementation=implementation)

    n = result.n_transactions
    min_sup_abs = result.min_support
    tx_sets = [Set(t) for t in transactions]

    cache = Dict{Tuple{Vararg{Int}}, Int}()
    for fi in result.itemsets
        cache[Tuple(fi.items)] = fi.support
    end

    rules = AssocRule[]
    seen = Set{Tuple{Tuple{Vararg{Int}}, Tuple{Vararg{Int}}}}()

    for fi in result.itemsets
        items = fi.items
        length(items) < 2 && continue

        sup_xy = fi.support
        sup_xy < min_sup_abs && continue

        for X in proper_subsets(items)
            Y = setdiff(items, X)
            isempty(Y) && continue

            sup_x = support_count(X, tx_sets, cache)
            sup_y = support_count(Y, tx_sets, cache)
            sup_x == 0 && continue
            sup_y == 0 && continue

            conf = sup_xy / sup_x
            conf < minconf && continue

            supp = sup_xy / n
            lift = conf / (sup_y / n)

            key = (Tuple(X), Tuple(Y))
            key in seen && continue
            push!(seen, key)

            push!(rules, AssocRule(X, Y, sup_xy, supp, conf, lift))
        end
    end

    sort!(rules, by = r -> (-r.lift, -r.confidence, -r.support_count, length(r.antecedent), r.antecedent, r.consequent))

    return rules, result
end

function write_rules_csv(path::String, rules::Vector{AssocRule})
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "rank,antecedent,consequent,support_count,support,confidence,lift")
        for (idx, r) in enumerate(rules)
            lhs = join(r.antecedent, " ")
            rhs = join(r.consequent, " ")
            println(io, string(
                idx, ",\"", lhs, "\",\"", rhs, "\",",
                r.support_count, ",",
                round(r.support, digits=6), ",",
                round(r.confidence, digits=6), ",",
                round(r.lift, digits=6),
            ))
        end
    end
end

function write_rules_csv(path::String, rules::Vector{AssocRule}, id_to_token::Dict{Int, String})
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "rank,antecedent,consequent,support_count,support,confidence,lift")
        for (idx, r) in enumerate(rules)
            lhs = join([id_to_token[x] for x in r.antecedent], " ")
            rhs = join([id_to_token[y] for y in r.consequent], " ")
            println(io, string(
                idx, ",\"", lhs, "\",\"", rhs, "\",",
                r.support_count, ",",
                round(r.support, digits=6), ",",
                round(r.confidence, digits=6), ",",
                round(r.lift, digits=6),
            ))
        end
    end
end

function main()
    cfg = MAIN_CONFIG
    encoded = read_transactions_encoded(cfg.input_path)
    txns = encoded.transactions

    rules, mining = mine_rules_from_closed_itemsets(txns, cfg.minsup, cfg.minconf; implementation=cfg.impl)
    top_rules = first(rules, min(cfg.topk, length(rules)))

    write_rules_csv(cfg.output_csv, top_rules, encoded.id_to_token)

    println("=== Market Basket Analysis (Retail) ===")
    println("transactions = $(mining.n_transactions)")
    println("minsup(abs)  = $(mining.min_support)")
    println("minconf      = $(cfg.minconf)")
    println("closed sets  = $(length(mining.itemsets))")
    println("rules found  = $(length(rules))")
    println("top-k saved  = $(length(top_rules)) -> $(cfg.output_csv)")

    for (i, r) in enumerate(top_rules)
        lhs = join([encoded.id_to_token[x] for x in r.antecedent], ",")
        rhs = join([encoded.id_to_token[y] for y in r.consequent], ",")
        println("[$i] {$lhs} => {$rhs} | sup=$(round(r.support, digits=4)) conf=$(round(r.confidence, digits=4)) lift=$(round(r.lift, digits=4))")
    end
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
