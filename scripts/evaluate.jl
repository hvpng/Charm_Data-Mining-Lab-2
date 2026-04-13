"""
scripts/evaluate.jl

Chạy toàn bộ 6 thực nghiệm bắt buộc (Chương 4) và xuất kết quả ra results/.

Cách dùng:
    julia --project=. scripts/evaluate.jl

Yêu cầu trước khi chạy:
    1. Đặt các file benchmark (.txt) vào data/benchmark/
    2. Chạy scripts/run_spmf.bat để sinh file reference SPMF
       → file reference lưu trong data/reference/spmf/
    3. julia --project=. scripts/evaluate.jl

Kết quả xuất ra results/:
    a_correctness.csv
    b_runtime_vs_minsup.csv
    c_itemset_count_vs_minsup.csv
    d_memory.csv
    e_scalability.csv
    f_avglen_impact.csv
"""

include(joinpath(@__DIR__, "..", "src", "algorithm", "charm.jl"))

using Random
using DelimitedFiles

# ─────────────────────────────────────────────────────────────────────────────
# Hằng số
# ─────────────────────────────────────────────────────────────────────────────

const ROOT    = normpath(joinpath(@__DIR__, ".."))
const DATADIR = joinpath(ROOT, "data", "benchmark")
const REFDIR  = joinpath(ROOT, "data", "reference", "spmf")
const OUTDIR  = joinpath(ROOT, "results")
const EVAL_SEED = 20260410

mkpath(OUTDIR)

# minsup points cho từng dataset — phải KHỚP với run_spmf.bat
# key = tên dataset, value = vector minsup dạng Int (%) giảm dần
const MINSUP_POINTS = Dict(
    "chess"       => [90, 80, 70, 60, 50, 40, 30],
    "mushrooms"   => [50, 40, 30, 20, 15, 10,  5],
    "retail"      => [7,  6,  5,  4,  3,  2,  1],
    # "accidents"   => [90, 80, 70, 60, 50, 40, 30],
    "T10I4D100K"  => [7,  6,  5,  4,  3,  2,  1],
)

# minsup override cho dataset lớn
const CORRECTNESS_MINSUP_OVERRIDE = Dict(
    "accidents" => 80,
)

# minsup mặc định nếu dataset không có trong MINSUP_POINTS
const DEFAULT_MINSUP_POINTS = [20, 15, 10, 7, 5, 3, 2]

# ─────────────────────────────────────────────────────────────────────────────
# Tiện ích
# ─────────────────────────────────────────────────────────────────────────────

"""
    write_csv(path, header, rows)

Ghi dữ liệu dạng bảng ra file CSV.

# Arguments
- `path`: Đường dẫn file đích.
- `header`: Vector tên cột.
- `rows`: Vector các row.

# Returns
`nothing`.

# Complexity
O(r × c).
"""
function write_csv(path, header, rows)
    open(path, "w") do f
        println(f, join(header, ","))
        for row in rows
            println(f, join(string.(row), ","))
        end
    end
    println("  → Đã ghi: $(basename(path))  ($(length(rows)) dòng)")
end

"""
    load_benchmark_datasets() -> Vector{Tuple{String, String, Vector{Vector{Int}}}}

Đọc tất cả file .txt/.dat trong data/benchmark/ theo SPMF format.

# Returns
- Vector các bộ `(tên_dataset, data_path, danh_sách_transaction)`.

# Complexity
O(tổng kích thước file).
"""
function load_benchmark_datasets()
    result = Tuple{String, String, Vector{Vector{Int}}}[]
    for fname in sort(readdir(DATADIR))
        (endswith(fname, ".txt") || endswith(fname, ".dat")) || continue
        name = splitext(fname)[1]
        path = joinpath(DATADIR, fname)
        txns = read_spmf_transactions(path)
        isempty(txns) && continue
        avg_len = round(sum(length(t) for t in txns) / length(txns), digits=1)
        push!(result, (name, path, txns))
        println("  Đã tải: $name  ($(length(txns)) txns, avg_len=$avg_len)")
    end
    return result
end

"""
    load_spmf_times() -> Dict{Tuple{String, Int}, Float64}

Đọc bảng thời gian SPMF từ `data/reference/spmf/spmf_times.csv`.

Format file:
`dataset,minsup_pct,time_ms`

# Returns
- `Dict{Tuple{String, Int}, Float64}`: Ánh xạ `(dataset, minsup_pct)` → thời gian (ms).

# Complexity
O(L) với L là số dòng trong file.
"""
function load_spmf_times()
    times_file = joinpath(REFDIR, "spmf_times.csv")
    isfile(times_file) || error("Thiếu file thời gian SPMF: $times_file")

    out = Dict{Tuple{String, Int}, Float64}()
    for line in eachline(times_file)
        s = strip(line)
        # Bỏ qua dòng trống, comment hoặc dòng tiêu đề
        (isempty(s) || startswith(s, "#") || startswith(s, "dataset")) && continue
        
        parts = split(s, ",")
        length(parts) >= 3 || error("Dòng không hợp lệ trong spmf_times.csv: $line")
        
        ds = strip(parts[1])
        # Nếu cột 2 là chữ "minsup_pct", đây là dòng tiêu đề -> bỏ qua
        strip(parts[2]) == "minsup_pct" && continue
        
        ms = parse(Int, strip(parts[2]))
        t  = parse(Float64, strip(parts[3]))
        out[(ds, ms)] = t
    end
    return out
end

"""
    validate_chapter4_requirements(datasets, spmf_times)

Kiểm tra điều kiện đầu vào để đảm bảo chạy đúng yêu cầu bắt buộc của Chương 4:
1. Có ít nhất 4 dataset benchmark.
2. Mỗi dataset có 5–7 điểm minsup giảm dần.
3. Mỗi điểm minsup đều có file reference SPMF cho correctness.
4. Mỗi điểm minsup đều có thời gian SPMF để vẽ so sánh runtime.

# Arguments
- `datasets`: Danh sách dataset từ `load_benchmark_datasets`.
- `spmf_times`: Bảng thời gian SPMF từ `load_spmf_times`.

# Returns
`nothing`.

# Complexity
O(D × P) với D là số dataset, P là số điểm minsup mỗi dataset.
"""
function validate_chapter4_requirements(datasets, spmf_times)
    length(datasets) >= 4 || error(
        "Chương 4 yêu cầu ít nhất 4 dataset benchmark; hiện chỉ có $(length(datasets)).",
    )

    for (name, _, _) in datasets
        pts = get_minsup_points(name)
        (5 <= length(pts) <= 7) || error(
            "Dataset '$name' cần 5–7 điểm minsup, hiện có $(length(pts)) điểm: $pts",
        )

        issorted(pts; rev=true) || error(
            "Minsup points của '$name' phải giảm dần (cao → thấp): $pts",
        )

        for minsup_pct in pts
            has_ref(name, minsup_pct) || error(
                "Thiếu reference SPMF cho '$name' ở minsup=$(minsup_pct)%: $(ref_path(name, minsup_pct))",
            )
            haskey(spmf_times, (name, minsup_pct)) || error(
                "Thiếu thời gian SPMF trong spmf_times.csv cho '$name', minsup=$(minsup_pct)%",
            )
        end
    end
    return nothing
end

"""
    get_minsup_points(name) -> Vector{Int}

Trả về danh sách minsup (%) cho dataset theo tên.
Các giá trị này phải khớp với những gì run_spmf.bat đã chạy.

# Arguments
- `name::String`: Tên dataset.

# Returns
- `Vector{Int}`: Minsup points (%).

# Complexity
O(1).
"""
get_minsup_points(name::String) = get(MINSUP_POINTS, name, DEFAULT_MINSUP_POINTS)

"""
    ref_path(dataset, minsup_pct) -> String

Trả về đường dẫn file reference SPMF cho dataset và minsup (%).

# Arguments
- `dataset::String`: Tên dataset.
- `minsup_pct::Int`: Minsup (%).

# Returns
- `String`: Đường dẫn file.

# Complexity
O(1).
"""
ref_path(dataset::String, minsup_pct::Int) =
    joinpath(REFDIR, "$(dataset)_minsup$(minsup_pct).txt")

"""
    has_ref(dataset, minsup_pct) -> Bool

Kiểm tra file reference SPMF có tồn tại không.

# Arguments
- `dataset::String`: Tên dataset.
- `minsup_pct::Int`: Minsup (%).

# Returns
- `Bool`.

# Complexity
O(1).
"""
has_ref(dataset::String, minsup_pct::Int) = isfile(ref_path(dataset, minsup_pct))

"""
    parse_spmf_time(dataset, minsup_pct) -> Union{Float64, Missing}

Đọc thời gian chạy SPMF từ file reference (nếu có ghi dòng #TIME).
SPMF không tự động ghi thời gian vào output file, nên trả về `missing`
trừ khi bạn thêm thủ công.

Lưu ý: Để lấy thời gian SPMF, cách đơn giản nhất là đọc output console
khi chạy run_spmf.bat và ghi vào file data/reference/spmf_times.csv thủ công.

# Arguments
- `dataset::String`: Tên dataset.
- `minsup_pct::Int`: Minsup (%).

# Returns
- `Float64` (ms) nếu tìm thấy, `missing` nếu không có.

# Complexity
O(1).
"""
function parse_spmf_time(dataset::String, minsup_pct::Int)
    spmf_times = load_spmf_times()
    return get(spmf_times, (dataset, minsup_pct), missing)
end

# ─────────────────────────────────────────────────────────────────────────────
# (a) Correctness
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_correctness(datasets) -> Vector

Thực nghiệm (a): kiểm tra tính đúng đắn bằng cách so sánh với SPMF reference.

Với mỗi dataset, dùng minsup ở giữa danh sách minsup_points.
So sánh:
  1. Số lượng itemset: implementation của nhóm vs SPMF
  2. Support từng itemset: tính match_ratio (tỉ lệ itemset khớp hoàn toàn)
  3. Cross-check: :basic vs :bitset phải 100% khớp nhau

Nếu file reference SPMF chưa có → fallback về cross-check :basic vs :bitset.

# Arguments
- `datasets`: Output của `load_benchmark_datasets()`.

# Returns
- Vector row CSV.

# Complexity
Dominated bởi mining + file I/O.
"""
function run_correctness(datasets)
    println("\n[a] Correctness")
    rows = Any[]
    for (name, _, txns) in datasets
        n = length(txns)
        pts = get_minsup_points(name)
        # Dùng minsup ở chính giữa danh sách
        minsup_pct = get(CORRECTNESS_MINSUP_OVERRIDE, name, pts[cld(length(pts), 2)])
        minsup_rel = minsup_pct / 100.0

        print("    $name (minsup=$(minsup_pct)%) ... ")

        # Chạy cả hai implementation
        r_basic  = charm(txns, minsup_rel; implementation=:basic)
        r_bitset = charm(txns, minsup_rel; implementation=:bitset)

        dict_basic  = Dict(Tuple(fi.items) => fi.support for fi in r_basic.itemsets)
        dict_bitset = Dict(Tuple(fi.items) => fi.support for fi in r_bitset.itemsets)

        # Cross-check basic vs bitset
        cross_total   = max(length(dict_basic), 1)
        cross_matched = count(kv -> get(dict_bitset, kv.first, -1) == kv.second, dict_basic)
        cross_ratio   = round(cross_matched / cross_total, digits=4)

        # So sánh bắt buộc với SPMF reference
        ref = read_spmf_itemsets(ref_path(name, minsup_pct))
        spmf_n     = length(ref)
        ref_total  = max(length(ref), 1)
        matched    = count(kv -> get(dict_bitset, kv.first, -1) == kv.second, ref)
        spmf_ratio = round(matched / ref_total, digits=4)
        println("SPMF=$(spmf_n) ours=$(length(r_bitset)) spmf_match=$(round(spmf_ratio*100,digits=2))% cross=$(round(cross_ratio*100,digits=2))%")

        push!(rows, (
            name, n, minsup_pct,
            length(r_basic), length(r_bitset),
            spmf_n, spmf_ratio,
            cross_ratio,
            (cross_ratio == 1.0 && spmf_ratio == 1.0) ? "OK" : "MISMATCH"
        ))
    end
    rows
end

# ─────────────────────────────────────────────────────────────────────────────
# (b) Runtime vs minsup  +  (c) Itemset count vs minsup
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_runtime_and_count(datasets) -> Vector

Thực nghiệm (b) + (c): thời gian chạy và số itemset theo minsup giảm dần.

Với mỗi điểm minsup:
  - Đo thời gian implementation :basic và :bitset của nhóm
  - Đọc thời gian SPMF từ file spmf_times.csv (nếu có)
  - Đếm số itemset output

# Arguments
- `datasets`: Output của `load_benchmark_datasets()`.

# Returns
- Vector row CSV.

# Complexity
O(|datasets| × |minsup_points| × mining_cost).
"""
function run_runtime_and_count(datasets, spmf_times)
    println("\n[b+c] Runtime & Count vs minsup (Bitset only vs SPMF)")
    rows = Any[]
    for (name, _, txns) in datasets
        pts = get_minsup_points(name)
        for minsup_pct in pts
            minsup_rel = minsup_pct / 100.0
            print("    $(name) $(minsup_pct)% ... ")

            # Chỉ chạy bản tối ưu để vẽ đồ thị so với SPMF
            t_bitset = @timed charm(txns, minsup_rel; implementation=:bitset)
            n_items  = length(t_bitset.value)
            spmf_t   = get(spmf_times, (name, minsup_pct), 0.0)

            println("bitset=$(round(t_bitset.time*1000,digits=1))ms  spmf=$(spmf_t)ms")
            push!(rows, (name, minsup_pct, minsup_rel, 0.0, # Gán basic = 0
                         round(t_bitset.time*1000, digits=2), round(spmf_t, digits=2), n_items))
        end
    end
    rows
end

# ─────────────────────────────────────────────────────────────────────────────
# (d) Memory
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_memory(datasets) -> Vector

Thực nghiệm (d): peak memory tại minsup trung bình, so sánh :basic vs :bitset.

Đo peak RAM bằng cách chạy mining trong tiến trình Julia con riêng cho từng
dataset/implementation và đọc `Sys.maxrss()` của tiến trình đó.

# Arguments
- `datasets`: Output của `load_benchmark_datasets()`.

# Returns
- Vector row CSV.

# Complexity
O(2 × (startup_cost + mining_cost) mỗi dataset).
"""
function run_memory(datasets)
    println("\n[d] Memory usage")
    rows = Any[]
    for (name, data_path, txns) in datasets
        n   = length(txns)
        pts = get_minsup_points(name)
        minsup_pct = pts[cld(length(pts), 2)]
        minsup_rel = minsup_pct / 100.0
        print("    $name (minsup=$(minsup_pct)%) ... ")

        s_basic  = _measure_peak_memory_subprocess(data_path, minsup_rel, :basic)
        s_bitset = _measure_peak_memory_subprocess(data_path, minsup_rel, :bitset)

        mb_basic  = round(s_basic.peak_mb,  digits=3)
        mb_bitset = round(s_bitset.peak_mb, digits=3)
        reduction = mb_basic > 0 ? round((1 - mb_bitset/mb_basic)*100, digits=1) : 0.0

        println("basic=$(mb_basic)MB  bitset=$(mb_bitset)MB  giảm=$(reduction)%")
        push!(rows, (
            name, n, minsup_pct,
            mb_basic, mb_bitset,
            round(s_basic.time_ms,  digits=2),
            round(s_bitset.time_ms, digits=2),
            reduction
        ))
    end
    rows
end

"""
    _measure_peak_memory_subprocess(data_path, minsup_rel, implementation)
        -> NamedTuple{(:peak_mb, :time_ms, :n_itemsets), Tuple{Float64, Float64, Int}}

Chạy CHARM trong tiến trình Julia con để đo peak RSS riêng cho một lần chạy.

# Arguments
- `data_path::String`: Đường dẫn file dataset SPMF.
- `minsup_rel::Float64`: Minsup tương đối trong (0, 1].
- `implementation::Symbol`: `:basic` hoặc `:bitset`.

# Returns
- Named tuple gồm peak memory (MB), thời gian (ms), và số itemset output.

# Complexity
O(startup_cost + mining_cost).
"""
function _measure_peak_memory_subprocess(
    data_path::String,
    minsup_rel::Float64,
    implementation::Symbol,
)
    charm_file = repr(joinpath(ROOT, "src", "algorithm", "charm.jl"))
    data_file  = repr(data_path)
    impl_expr  = repr(implementation)

    expr = """
include($charm_file)
txns = read_spmf_transactions($data_file)
stats = @timed charm(txns, $minsup_rel; implementation=$impl_expr)
rss = Sys.maxrss()
rss_mb = Sys.islinux() ? rss / 1024 : rss / 1024^2
println("PEAK_MB=\$(rss_mb);TIME_MS=\$(stats.time * 1000);NITEMS=\$(length(stats.value))")
"""

    cmd = `$(Base.julia_cmd()) --project=$(ROOT) -e $expr`
    out = read(cmd, String)
    m = match(r"PEAK_MB=([0-9eE+\.-]+);TIME_MS=([0-9eE+\.-]+);NITEMS=([0-9]+)", out)
    isnothing(m) && error("Không parse được output đo memory: $out")

    return (
        peak_mb = parse(Float64, m.captures[1]),
        time_ms = parse(Float64, m.captures[2]),
        n_itemsets = parse(Int, m.captures[3]),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# (e) Scalability
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_scalability(datasets) -> Vector

Thực nghiệm (e): thời gian chạy khi tăng dần kích thước CSDL.

Ưu tiên dùng "retail" hoặc "accidents". Tạo subset 10/25/50/75/100%
giao dịch (lấy liên tiếp từ đầu file — không shuffle để reproducible).
Minsup cố định = minsup cao nhất của dataset (để tránh timeout ở 100%).

# Arguments
- `datasets`: Output của `load_benchmark_datasets()`.

# Returns
- Vector row CSV.

# Complexity
O(5 × mining_cost_at_full_size).
"""
function run_scalability(datasets)
    println("\n[e] Scalability")

    preferred = ["retail"]
    chosen = nothing
    for pref in preferred
        idx = findfirst(d -> d[1] == pref, datasets)
        if !isnothing(idx)
            chosen = datasets[idx]
            break
        end
    end
    # Fallback: dataset lớn nhất
    isnothing(chosen) && (chosen = datasets[argmax(d -> length(d[2]), datasets)])

    name, _, txns = chosen
    pts = get_minsup_points(name)
    minsup_pct = pts[1]  # minsup cao nhất → an toàn khi chạy full dataset
    minsup_rel = minsup_pct / 100.0
    println("  Dùng dataset: $name  minsup=$(minsup_pct)%")

    rows = Any[]
    for frac in [0.10, 0.25, 0.50, 0.75, 1.00]
        n_sub  = max(1, floor(Int, frac * length(txns)))
        subset = txns[1:n_sub]
        stats  = @timed charm(subset, minsup_rel; implementation=:bitset)
        t_ms   = round(stats.time * 1000, digits=2)
        println("    $(Int(frac*100))%: $n_sub txns → $(t_ms)ms  itemsets=$(length(stats.value))")
        push!(rows, (name, minsup_pct, Int(frac*100), n_sub, t_ms, length(stats.value)))
    end
    rows
end

# ─────────────────────────────────────────────────────────────────────────────
# (f) Ảnh hưởng độ dài giao dịch
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_avglen_impact(; n_txn=3000, n_items=200, minsup_pct=5) -> Vector

Thực nghiệm (f): ảnh hưởng của avg transaction length lên thời gian và số itemset.

Sinh dữ liệu tổng hợp với seed cố định. Giữ nguyên n_txn và n_items,
chỉ tăng dần avg_len: 5 → 10 → 15 → 20 → 30.

Lý thuyết CHARM:
  - Tidset của mỗi item dày hơn khi giao dịch dài hơn
    → intersection tốn kém hơn (O(n) cho BitVector)
  - Số closed itemset tăng nhanh theo avg_len
  - Thời gian tăng phi tuyến (thường ~ polynomial hoặc exponential)

# Arguments
- `n_txn`: Số giao dịch tổng hợp.
- `n_items`: Phạm vi item ID (1..n_items).
- `minsup_pct`: Minsup (%).

# Returns
- Vector row CSV.

# Complexity
O(5 × mining_cost).
"""
function run_avglen_impact(; n_txn=2000, n_items=100, minsup_pct=10)
    println("\n[f] Avg length impact (Bitset only)")
    minsup_rel = minsup_pct / 100.0
    rows = Any[]
    for target_len in [5, 10, 15, 20, 30]
        txns = [sort!(Random.randperm(n_items)[1:target_len]) for _ in 1:n_txn]
        s_bitset = @timed charm(txns, minsup_rel; implementation=:bitset)
        
        t_ms = round(s_bitset.time*1000, digits=2)
        println("    len=$target_len -> $(t_ms)ms, items=$(length(s_bitset.value))")
        push!(rows, (target_len, target_len, n_txn, minsup_pct, 0.0, t_ms, 0.0, 
                     round(s_bitset.bytes/1024^2, digits=3), length(s_bitset.value)))
    end
    rows
end

# ─────────────────────────────────────────────────────────────────────────────
# Hướng dẫn spmf_times.csv
# ─────────────────────────────────────────────────────────────────────────────

"""
    print_spmf_times_guide()

In hướng dẫn tạo file spmf_times.csv để lưu thời gian chạy SPMF thủ công.

SPMF không ghi thời gian vào output file — bạn cần đọc từ console output
của run_spmf.bat rồi ghi vào file này.

# Returns
`nothing`.
"""
function print_spmf_times_guide()
    times_file = joinpath(REFDIR, "spmf_times.csv")
    if !isfile(times_file)
        println("\n" * "─"^60)
        println("LƯU Ý: Để so sánh thời gian với SPMF trong biểu đồ (b),")
        println("hãy tạo file: $times_file")
        println("Format: dataset,minsup_pct,time_ms")
        println("Ví dụ:")
        println("  chess,80,12.5")
        println("  chess,70,18.3")
        println("  mushroom,50,45.2")
        println("  ...")
        println("Thời gian lấy từ console output khi chạy run_spmf.bat")
        println("─"^60)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

"""
    main()

Chạy toàn bộ 6 thực nghiệm và ghi kết quả vào results/.

# Returns
`nothing`.

# Complexity
Dominated bởi tổng chi phí mining trên tất cả datasets và scenarios.
"""
function main()
    # Đặt seed toàn cục ngay đầu để đảm bảo reproducibility hoàn toàn
    Random.seed!(EVAL_SEED)

    println("=" ^ 60)
    println("Thực nghiệm và đánh giá")
    println("Dataset dir  : $DATADIR")
    println("Reference dir: $REFDIR")
    println("Output dir   : $OUTDIR")
    println("=" ^ 60)

    print_spmf_times_guide()

    println("\nWarm-up JIT (tránh inflate thời gian đo lần đầu)...")
    _warmup_txns = [[1,2,3],[2,3],[1,3],[1,2],[1,2,3]]
    charm(_warmup_txns, 2; implementation=:basic)
    charm(_warmup_txns, 2; implementation=:bitset)
    println("  Done.")

    println("\nĐang tải datasets...")
    datasets = load_benchmark_datasets()
    if isempty(datasets)
        println("\nCẢNH BÁO: Không tìm thấy dataset trong $DATADIR")
        println("Tải datasets và đặt vào thư mục đó rồi chạy lại.")
        return
    end

    acc_idx = findfirst(d -> d[1] == "accidents", datasets)
    if !isnothing(acc_idx)
        acc_ds = splice!(datasets, acc_idx)
        push!(datasets, acc_ds)
    end

    spmf_times = load_spmf_times()
    validate_chapter4_requirements(datasets, spmf_times)

    println("Đã tải $(length(datasets)) dataset(s): $(join(first.(datasets), ", "))")

    # ── (a) Correctness ─────────────────────────────────────────
    # rows_a = run_correctness(datasets)
    # write_csv(joinpath(OUTDIR, "a_correctness.csv"),
    #     ["dataset", "n_transactions", "minsup_pct",
    #      "n_itemsets_basic", "n_itemsets_bitset",
    #      "spmf_n_itemsets", "spmf_match_ratio",
    #      "cross_match_ratio", "status"],
    #     rows_a)

    # ── (b) + (c) Runtime & Count ────────────────────────────────
    # rows_bc = run_runtime_and_count(datasets, spmf_times)
    # write_csv(joinpath(OUTDIR, "b_runtime_vs_minsup.csv"),
    #     ["dataset", "minsup_pct", "minsup_rel",
    #      "time_basic_ms", "time_bitset_ms", "time_spmf_ms", "n_itemsets"],
    #     rows_bc)
    # write_csv(joinpath(OUTDIR, "c_itemset_count_vs_minsup.csv"),
    #     ["dataset", "minsup_pct", "n_itemsets"],
    #     [(r[1], r[2], r[7]) for r in rows_bc])

    # ── (d) Memory ───────────────────────────────────────────────
    # rows_d = run_memory(datasets)
    # write_csv(joinpath(OUTDIR, "d_memory.csv"),
    #     ["dataset", "n_transactions", "minsup_pct",
    #      "peak_basic_MB", "peak_bitset_MB",
    #      "time_basic_ms", "time_bitset_ms", "reduction_pct"],
    #     rows_d)

    # ── (e) Scalability ──────────────────────────────────────────
    # rows_e = run_scalability(datasets)
    # write_csv(joinpath(OUTDIR, "e_scalability.csv"),
    #     ["dataset", "minsup_pct", "fraction_pct",
    #      "n_transactions", "time_ms", "n_itemsets"],
    #     rows_e)

    # ── (f) Avg length impact ────────────────────────────────────
    rows_f = run_avglen_impact()
    write_csv(joinpath(OUTDIR, "f_avglen_impact.csv"),
        ["target_avg_len", "actual_avg_len", "n_transactions", "minsup_pct",
         "time_basic_ms", "time_bitset_ms",
         "bytes_basic_MB", "bytes_bitset_MB", "n_itemsets"],
        rows_f)

    println("\n" * "=" ^ 60)
    println("Hoàn thành! Kết quả trong: $OUTDIR")
    println("Dùng notebooks/demo.ipynb để vẽ biểu đồ.")
    println("=" ^ 60)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end