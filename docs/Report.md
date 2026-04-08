# Báo cáo cài đặt và thực nghiệm

## Chương 3: Cài đặt

### 3.3.1. Môi trường và công cụ
- Ngôn ngữ: Julia >= 1.9
- Kỹ thuật dùng trong cài đặt:
  - multiple dispatch cho phép dùng chung bộ khung mining với 2 kiểu tidset (`Set` và `BitVector`)
  - `BitVector` (BitArray) cho bản tối ưu
  - generator expression trong các bước gom item/chuẩn hóa
  - `DataStructures.jl` (`DefaultDict`, `OrderedDict`) cho xây dựng vertical DB và so khớp kết quả

### 3.3.2. Yêu cầu cài đặt
- Cài đặt from-scratch: `src/algorithm/charm.jl`
- Xuất toàn bộ frequent itemset + support: `output_mode=:all`
- Xuất closed frequent itemset: `output_mode=:closed`
- I/O chuẩn SPMF:
  - Input: transaction per line, space-separated
  - Output: `item1 item2 ... #SUP: n`
- CLI:
  - `src/cli.jl` với tham số `--input --output --minsup --mode --impl`
- Tự động kiểm thử đúng đắn trên 5 CSDL:
  - `tests/test_correctness.jl`
  - so khớp 100% với file tham chiếu SPMF-format trong `data/reference/spmf`
- Tối ưu:
  - bản `:basic` (Set tidset)
  - bản `:bitset` (BitVector tidset)
  - benchmark trong `tests/test_benchmark.jl`

## Chương 4: Thực nghiệm và đánh giá

### 4.1. Dataset benchmark
Script `scripts/evaluate.jl` hỗ trợ chạy các tập chuẩn:
- chess
- mushroom
- retail
- accidents
- T10I4D100K

Đặt file vào `data/benchmark/*.txt`.

### 4.2. Thực nghiệm bắt buộc
Script xuất CSV trong `results/` cho toàn bộ mục:
1. Correctness vs reference (`correctness.csv`)
2. Runtime theo minsup (`runtime_vs_minsup.csv`)
3. Output size theo minsup (`runtime_vs_minsup.csv`, cột `n_itemsets`)
4. Memory basic vs optimized (`memory_basic_vs_opt.csv`)
5. Scalability theo kích thước CSDL (`scalability.csv`)
6. Ảnh hưởng độ dài giao dịch (`avglen_impact.csv`)

### 4.3. Phân tích kết quả (khung)
- Điểm mạnh:
  - bản bitset thường giảm thời gian và bộ nhớ ở dữ liệu lớn
  - kiến trúc tách rõ mining core / I/O / evaluation
- Điểm yếu:
  - số lượng FI tăng rất nhanh khi minsup thấp
  - baseline Set có chi phí giao cắt cao
- Hướng tối ưu tiếp theo:
  1. Prefix-preserving compression cho tidset/diffset
  2. Song song hóa DFS theo nhánh prefix độc lập
