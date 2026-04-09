using DataStructures: OrderedDict

function normalize_transactions(transactions::Vector{<:AbstractVector})::Vector{Vector{Int}}
    [sort(unique(Int.(t))) for t in transactions]
end

function read_spmf_transactions(filepath::AbstractString)::Vector{Vector{Int}}
    txns = Vector{Vector{Int}}()
    open(filepath, "r") do f
        for line in eachline(f)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "#") && continue
            push!(txns, sort(unique(parse.(Int, split(s)))))
        end
    end
    txns
end

read_transactions(filepath::AbstractString; kwargs...) = read_spmf_transactions(filepath)

function resolve_min_support(min_support::Real, n_transactions::Int)::Int
    min_support <= 0 && error("min_support must be > 0")
    if min_support isa AbstractFloat && min_support <= 1.0
        return max(1, ceil(Int, min_support * n_transactions))
    end
    return Int(min_support)
end

function write_spmf_itemsets(result::MiningResult, filepath::AbstractString)
    sorted_itemsets = sort(result.itemsets; by = fi -> (length(fi.items), fi.items, fi.support))
    open(filepath, "w") do f
        for fi in sorted_itemsets
            println(f, "$(join(fi.items, ' ')) #SUP: $(fi.support)")
        end
    end
end

function print_results(result::MiningResult; io::IO=stdout)
    println(io, "Found $(length(result)) frequent itemsets (mode=$(result.output_mode), minsup=$(result.min_support))")
    for fi in sort(result.itemsets; by = x -> (-x.support, x.items))
        println(io, "  {$(join(fi.items, ", "))} support=$(fi.support)")
    end
end

function read_spmf_itemsets(filepath::AbstractString)
    out = OrderedDict{Tuple{Vararg{Int}}, Int}()
    open(filepath, "r") do f
        for line in eachline(f)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "#") && continue
            parts = split(s, "#SUP:")
            length(parts) == 2 || error("Invalid SPMF output line: $line")
            items = isempty(strip(parts[1])) ? Int[] : parse.(Int, split(strip(parts[1])))
            sup = parse(Int, strip(parts[2]))
            out[Tuple(sort(items))] = sup
        end
    end
    out
end

function result_as_dict(result::MiningResult)
    OrderedDict(Tuple(fi.items) => fi.support for fi in sort(result.itemsets; by = x -> (length(x.items), x.items, x.support)))
end

function exact_match_ratio(result::MiningResult, reference::OrderedDict{Tuple{Vararg{Int}}, Int})
    mine = result_as_dict(result)
    total = max(length(reference), 1)
    matched = count(kv -> haskey(mine, kv.first) && mine[kv.first] == kv.second, reference)
    matched / total
end
