using Test

# REPO_ROOT, DATA, REF được định nghĩa trong runtests.jl trước khi include file này
include(joinpath(REPO_ROOT, "src", "algorithm", "charm.jl"))

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

"""
    as_dict(r::MiningResult) -> Dict{Tuple{Vararg{Int}}, Int}

Chuyển một `MiningResult` thành dictionary ánh xạ itemset → support,
phục vụ so sánh bằng nhau trong các test.

# Arguments
- `r::MiningResult`: Kết quả khai thác cần chuyển đổi.

# Returns
- `Dict{Tuple{Vararg{Int}}, Int}`: Key là tuple item ID đã sắp xếp,
  value là support tuyệt đối tương ứng.

# Complexity
O(m) với m là số itemset trong `r`.
"""
function as_dict(r::MiningResult)
    Dict(Tuple(sort(collect(fi.items))) => fi.support for fi in r.itemsets)
end

"""
    read_spmf_reference(path::String) -> Dict{Tuple{Vararg{Int}}, Int}

Đọc file kết quả tham chiếu định dạng SPMF thành dictionary
ánh xạ closed itemset → support tuyệt đối.

Mỗi dòng hợp lệ có dạng: `1 2 3 #SUP: 150`
Dòng không chứa `#SUP:` sẽ bị bỏ qua.

# Arguments
- `path::String`: Đường dẫn tới file tham chiếu SPMF.

# Returns
- `Dict{Tuple{Vararg{Int}}, Int}`: Key là tuple item ID đã sắp xếp,
  value là support tuyệt đối.

# Complexity
O(L · w) với L là số dòng và w là độ rộng dòng tối đa.
"""
function read_spmf_reference(path::String)
    result = Dict{Tuple{Vararg{Int}}, Int}()
    open(path) do f
        for line in eachline(f)
            line = strip(line)
            isempty(line) && continue
            parts = split(line, "#SUP:")
            length(parts) != 2 && continue
            items = Tuple(sort(parse.(Int, split(strip(parts[1])))))
            sup   = parse(Int, strip(parts[2]))
            result[items] = sup
        end
    end
    return result
end

"""
    check_against_reference(txns, minsup, ref_path; label) -> Nothing

Chạy CHARM trên `txns` với ngưỡng support `minsup` (tuyệt đối hoặc tỉ lệ), sau đó
so sánh closed itemsets thu được với file tham chiếu SPMF. In tóm tắt độ
chính xác và assert kết quả phải khớp hoàn toàn với tham chiếu.

# Arguments
- `txns`: Transaction database từ `read_spmf_transactions`.
- `minsup::Real`: Ngưỡng support (tuyệt đối nếu `>1`, tỉ lệ nếu `∈ (0,1]`).
- `ref_path::String`: Đường dẫn file tham chiếu SPMF cho cặp (dataset, minsup).
- `label::String` (keyword, mặc định `""`): Nhãn hiển thị trong output.

# Returns
- `Nothing`. Side effects: in tóm tắt và kích hoạt `@test`.

# Complexity
O(T_charm + m) với T_charm là thời gian chạy CHARM và m là số itemset
trong tham chiếu.
"""
function check_against_reference(txns, minsup::Real, ref_path::String; label::String="")
    ref = read_spmf_reference(ref_path)
    res = charm(txns, minsup; implementation=:bitset)
    got = as_dict(res)

    n_ref   = length(ref)
    n_got   = length(got)
    correct = count(k -> get(got, k, -1) == ref[k], keys(ref))
    extra   = count(k -> !haskey(ref, k), keys(got))
    pct     = n_ref == 0 ? 100.0 : round(correct / n_ref * 100, digits=2)

    println("  [$label] ref=$n_ref got=$n_got correct=$correct extra=$extra accuracy=$(pct)%")

    @test got == ref
end

# ─────────────────────────────────────────────
# Dataset registry
# ─────────────────────────────────────────────

"""
    CORRECTNESS_DATASETS -> Vector{Tuple}

Registry các dataset dùng trong kiểm thử tính đúng đắn. Mỗi entry là tuple:
    `(display_name, data_path, [(minsup_abs, ref_filename), ...])`

- `display_name::String`: Nhãn hiển thị trong output test.
- `data_path::String`: Đường dẫn tuyệt đối tới file transaction SPMF.
- `cases`: Danh sách `(minsup_abs, ref_filename)` — mỗi cặp tương ứng một
  lần chạy test, so sánh với file tham chiếu trong `data/reference/spmf/`.

Dataset toy1–toy5 là ví dụ tay từ Chương 2, dùng minsup tuyệt đối = 2
(tương ứng 40% trên 5 transaction). Dataset benchmark (chess, mushrooms,
accidents, retail, T10I4D100K) dùng để kiểm tra tính đúng đắn ở quy mô lớn.
"""
const CORRECTNESS_DATASETS = [
    # Example dataset
    ("example1 (hand example)", joinpath(DATA, "toy", "example1.txt"),
        [(0.50, "example1_minsup50.txt")]),

    ("example2 (hand example)", joinpath(DATA, "toy", "example2.txt"),
        [(0.50, "example2_minsup50.txt")]),

    # ── Benchmark datasets ────────────────────────────────────────────────
    ("chess", joinpath(DATA, "benchmark", "chess.txt"),
        [(Int(round(0.50 * 3196)), "chess_minsup50.txt"),
         (Int(round(0.80 * 3196)), "chess_minsup80.txt")]),

    ("mushrooms", joinpath(DATA, "benchmark", "mushrooms.txt"),
        [(Int(round(0.20 * 8416)), "mushrooms_minsup20.txt"),
         (Int(round(0.50 * 8416)), "mushrooms_minsup50.txt")]),

    ("T10I4D100K", joinpath(DATA, "benchmark", "T10I4D100K.txt"),
        [(Int(round(0.01 * 100000)), "T10I4D100K_minsup1.txt"),
         (Int(round(0.05 * 100000)), "T10I4D100K_minsup5.txt")]),
]

# ─────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────

@testset "CHARM correctness vs SPMF reference" begin

    # ── 1. Tính chất closed-itemset (sanity check trên example1) ──────────────
    @testset "Closed-mode subset property" begin
        txns    = read_spmf_transactions(joinpath(DATA, "toy", "example1.txt"))
        cls_res = charm(txns, 0.4; implementation=:bitset)
        cls_map = as_dict(cls_res)

        # Không có closed itemset nào là subset đúng của closed itemset khác
        # với cùng support — đây là định nghĩa của closed itemset
        for fi in cls_res.itemsets, fj in cls_res.itemsets
            if length(fj.items) > length(fi.items) && fi.support == fj.support
                @test !all(in(fj.items), fi.items)
            end
        end
        println("  [closed subset property] OK ($(length(cls_res.itemsets)) closed itemsets)")
    end

    # ── 2. So sánh với ground truth SPMF trên tất cả dataset ─────────────
    for (name, data_path, cases) in CORRECTNESS_DATASETS
        @testset "$name" begin
            # println("  [start dataset] $name")
            @test isfile(data_path)
            txns = read_spmf_transactions(data_path)
            # println("  [dataset loaded] $name: $(length(txns)) transactions")

            for (minsup, ref_file) in cases
                ref_path = joinpath(REF, ref_file)
                @test isfile(ref_path)
                # println("    [start case] $name | $ref_file | minsup=$minsup")
                check_against_reference(txns, minsup, ref_path;
                                        label="$name | $ref_file")
            end
        end
    end

end

println("\nAll correctness tests passed ✓")