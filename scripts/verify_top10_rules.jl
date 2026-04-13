include(joinpath(@__DIR__, "market_basket_rules.jl"))

function unquote_token(s::String)
    t = strip(s)
    if startswith(t, '"') && endswith(t, '"') && length(t) >= 2
        return t[2:end-1]
    end
    return t
end

function parse_csv_line(line::String)
    parts = String[]
    buf = IOBuffer()
    in_quotes = false
    for c in line
        if c == '"'
            in_quotes = !in_quotes
        elseif c == ',' && !in_quotes
            push!(parts, String(take!(buf)))
        else
            print(buf, c)
        end
    end
    push!(parts, String(take!(buf)))
    return parts
end

function main()
    root = normpath(joinpath(@__DIR__, ".."))
    csv_path = joinpath(root, "results", "retail_top10_rules.csv")
    data_path = joinpath(root, "data", "benchmark", "retail.txt")

    enc = read_transactions_encoded(data_path)
    txs = [Set(t) for t in enc.transactions]
    n = length(enc.transactions)

    token_to_id = Dict(v => k for (k, v) in enc.id_to_token)

    lines = readlines(csv_path)
    ok = true

    for line in lines[2:end]
        p = parse_csv_line(line)
        rank = parse(Int, p[1])
        lhs_tokens = filter(!isempty, split(unquote_token(p[2]), " "))
        rhs_tokens = filter(!isempty, split(unquote_token(p[3]), " "))

        X = [token_to_id[t] for t in lhs_tokens]
        Y = [token_to_id[t] for t in rhs_tokens]
        XY = Set(vcat(X, Y))

        sup_xy = count(t -> issubset(XY, t), txs)
        sup_x = count(t -> issubset(Set(X), t), txs)
        sup_y = count(t -> issubset(Set(Y), t), txs)

        conf = sup_xy / sup_x
        lift = conf / (sup_y / n)

        csv_sup = parse(Int, p[4])
        csv_conf = parse(Float64, p[6])
        csv_lift = parse(Float64, p[7])

        if csv_sup != sup_xy || abs(csv_conf - conf) > 1e-6 || abs(csv_lift - lift) > 1e-6
            ok = false
            println("Mismatch at rank $rank")
        end
    end

    println(ok ? "Top10 verification: PASS" : "Top10 verification: FAIL")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
