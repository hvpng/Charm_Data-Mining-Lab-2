using Test

# REPO_ROOT, DATA, BENCH được định nghĩa trong runtests.jl trước khi include file này
include(joinpath(REPO_ROOT, "src", "algorithm", "charm.jl"))

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

"""
    timed_run(f) -> Tuple{Any, Float64}

Thực thi hàm không tham số `f` và trả về kết quả cùng thời gian chạy
tính bằng millisecond.

# Arguments
- `f`: Hàm không tham số cần đo thời gian.

# Returns
- `(result, elapsed_ms)`: Kết quả trả về của `f` và thời gian chạy (ms).

# Complexity
O(T_f) với T_f là thời gian chạy của `f`.
"""
function timed_run(f)
    t0         = time()
    result     = f()
    elapsed_ms = (time() - t0) * 1000
    return result, elapsed_ms
end

"""
    run_speedup_table(name, txns, minsup_pcts, n_txns) -> Vector{Float64}

Chạy CHARM với implementation `:basic` và `:bitset` trên nhiều mức minsup
cho một dataset. In bảng so sánh tốc độ, assert kết quả hai bên giống nhau
và bitset phải nhanh hơn basic, trả về danh sách speedup ratio.

# Arguments
- `name::String`: Tên dataset hiển thị trong output.
- `txns`: Transaction database từ `read_spmf_transactions`.
- `minsup_pcts::Vector{Float64}`: Danh sách minsup tương đối ∈ (0, 1].
- `n_txns::Int`: Tổng số transaction, dùng để đổi minsup sang tuyệt đối.

# Returns
- `Vector{Float64}`: Danh sách speedup ratio (`t_basic / t_bitset`)
  cho từng mức minsup.

# Complexity
O(k · T_charm) với k = length(minsup_pcts).
"""
function run_speedup_table(name::String, txns, minsup_pcts::Vector{Float64}, n_txns::Int)
    println("\nRuntime vs minsup — $name (basic vs bitset, closed itemsets)")
    speedups = Float64[]
    for pct in minsup_pcts
        minsup_abs = Int(round(pct * n_txns))
        rb, tb = timed_run(() -> charm(txns, minsup_abs; implementation=:basic))
        ro, to = timed_run(() -> charm(txns, minsup_abs; implementation=:bitset))

        # Correctness: hai implementation phải cho cùng kết quả
        @test Dict(Tuple(fi.items) => fi.support for fi in rb.itemsets) ==
              Dict(Tuple(fi.items) => fi.support for fi in ro.itemsets)
        @test tb > 0.0
        @test to > 0.0

        speedup = tb / to
        # Bitset phải nhanh hơn basic
        @test speedup > 1.0

        push!(speedups, speedup)
        println("  minsup=$(Int(round(pct*100)))%  " *
                "basic=$(round(tb, digits=2))ms  " *
                "bitset=$(round(to, digits=2))ms  " *
                "speedup=$(round(speedup, digits=2))x  " *
                "itemsets=$(length(ro))")
    end
    return speedups
end

"""
    run_memory_comparison(name, txns, minsup_abs) -> Float64

Đo lường bộ nhớ heap cấp phát cho cả hai implementation `:basic` và
`:bitset` của CHARM tại một mức minsup cố định. In tóm tắt, assert
bitset dùng ít bộ nhớ hơn, và trả về tỉ lệ giảm bộ nhớ.

# Arguments
- `name::String`: Tên dataset hiển thị trong output.
- `txns`: Transaction database từ `read_spmf_transactions`.
- `minsup_abs::Int`: Ngưỡng support tuyệt đối.

# Returns
- `Float64`: Tỉ lệ giảm bộ nhớ `1 - bytes_bitset / bytes_basic` ∈ (0, 1).
  Ví dụ `0.40` nghĩa là bitset dùng ít hơn 40% so với basic.

# Complexity
O(T_charm) — dominated bởi hai lần chạy CHARM.
"""
function run_memory_comparison(name::String, txns, minsup_abs::Int)
    stats_basic = @timed charm(txns, minsup_abs; implementation=:basic)
    stats_opt   = @timed charm(txns, minsup_abs; implementation=:bitset)

    @test stats_basic.time  > 0
    @test stats_opt.time    > 0
    @test stats_basic.bytes > 0
    @test stats_opt.bytes   > 0

    # Bitset phải dùng ít bộ nhớ hơn basic
    @test stats_opt.bytes < stats_basic.bytes

    reduction = 1.0 - stats_opt.bytes / stats_basic.bytes
    println("  Memory [$name minsup=$minsup_abs]: " *
            "basic=$(round(stats_basic.bytes/1024^2, digits=2)) MiB  " *
            "bitset=$(round(stats_opt.bytes/1024^2,  digits=2)) MiB  " *
            "reduction=$(round(reduction*100, digits=2))%")
    return reduction
end

# ─────────────────────────────────────────────
# Dataset registry
# ─────────────────────────────────────────────

"""
    BENCH_DATASETS -> Vector{NamedTuple}

Tập benchmark dùng trong kiểm thử tối ưu hóa tốc độ/bộ nhớ.
Theo yêu cầu hiện tại, chỉ chạy đúng 1 dataset đại diện: `chess`.

# Fields mỗi entry
- `name::String`: Tên dataset hiển thị trong output.
- `path::String`: Đường dẫn tuyệt đối tới file transaction SPMF.
- `n_txns::Int`: Tổng số transaction (để kiểm tra và đổi minsup).
- `minsup_pcts::Vector{Float64}`: Dải minsup tương đối để sweep.
- `mem_minsup_pct::Float64`: Minsup tương đối dùng cho so sánh bộ nhớ.
"""
const BENCH_DATASETS = [
    (name           = "chess",
     path           = joinpath(BENCH, "chess.txt"),
     n_txns         = 3196,
     minsup_pcts    = [0.80, 0.70, 0.60],
     mem_minsup_pct = 0.60),
]

# ─────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────

@testset "Benchmark + optimization comparison" begin
    println("Running benchmark on a single dataset: chess")

    all_speedups   = Float64[]
    all_reductions = Float64[]

    for ds in BENCH_DATASETS
        @testset "$(ds.name)" begin
            @test isfile(ds.path)
            txns = read_spmf_transactions(ds.path)
            @test length(txns) == ds.n_txns

            # Đo speedup tốc độ trên nhiều mức minsup
            speedups = run_speedup_table(ds.name, txns, ds.minsup_pcts, ds.n_txns)
            append!(all_speedups, speedups)

            # Đo mức giảm bộ nhớ tại minsup trung bình
            mem_abs   = Int(round(ds.mem_minsup_pct * ds.n_txns))
            reduction = run_memory_comparison(ds.name, txns, mem_abs)
            push!(all_reductions, reduction)
        end
    end

    # ── Tóm tắt toàn cục ──────────────────────────────────────────────────
    avg_speedup   = round(sum(all_speedups)   / length(all_speedups),        digits=2)
    avg_reduction = round(sum(all_reductions) / length(all_reductions) * 100, digits=2)

    println("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("  Optimization summary (bitset vs basic, closed mode)")
    println("  Average speedup         : $(avg_speedup)x")
    println("  Average memory reduction: $(avg_reduction)%")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Kết luận tổng thể: bitset phải tốt hơn cả tốc độ lẫn bộ nhớ
    @test avg_speedup   > 1.0
    @test avg_reduction > 0.0

end

println("\nAll benchmark tests passed ✓")