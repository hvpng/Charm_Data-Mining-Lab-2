# Bao cao Chuong 3 - Cai dat (theo de bai va code hien tai)

## 3.3.1. Moi truong va cong cu

- Ngon ngu su dung: Julia.
- Rang buoc de bai: Julia >= 1.9. Moi truong da kiem tra tai may hien tai: Julia 1.12.6.
- Quan ly du an: [Project.toml](Project.toml), [Manifest.toml](Manifest.toml).
- Thu vien bo tro: DataStructures.jl (dung OrderedDict trong [src/utils.jl](src/utils.jl)).

### Cac dac trung Julia da ap dung

- Multiple dispatch tren tidset:
  - Nhom ham xu ly cho BitVector va Set duoc khai bao rieng trong [src/algorithm/charm.jl](src/algorithm/charm.jl).
- BitArray (BitVector):
  - Backend toi uu su dung BitVector de tinh support va giao tidset trong [src/algorithm/charm.jl](src/algorithm/charm.jl).
- Generator expression/comprehension:
  - Dung trong cac ham chuan hoa/chuyen doi ket qua tai [src/utils.jl](src/utils.jl).

Ket luan 3.3.1: Dat yeu cau uu tien Julia va co khai thac cac dac trung ngon ngu theo de bai.

## 3.3.2. Yeu cau cai dat

### Bang doi chieu yeu cau - bang chung - trang thai

| Yeu cau de bai                                                                            | Bang chung trong code hien tai                                                                                                                                     | Trang thai hien tai                                 |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- |
| Cai dat tu dau (from scratch)                                                             | Loi giai CHARM duoc cai dat truc tiep trong [src/algorithm/charm.jl](src/algorithm/charm.jl), khong dung thu vien FIM ben ngoai                                    | Dat                                                 |
| Cai dat co ban: xuat tat ca frequent itemset + support, khop SPMF                         | Ham chinh tra ve ket qua mode closed trong [src/algorithm/charm.jl](src/algorithm/charm.jl)                                                                        | Chua dat day du theo cau chu de bai ve all frequent |
| Tai tao ket qua dung: unit test >= 5 CSDL, co CSDL vi du tay Chuong 2, bao cao ti le dung | Co khung so sanh reference o [tests/test_correctness.jl](tests/test_correctness.jl), nhung nhieu case toy dang comment va co case benchmark phu thuoc file chua co | Dat mot phan                                        |
| Toi uu bo nho va toc do                                                                   | Co 2 implementation basic va bitset trong [src/algorithm/charm.jl](src/algorithm/charm.jl); co benchmark trong [tests/test_benchmark.jl](tests/test_benchmark.jl)  | Dat ve mat cai dat; phu thuoc du lieu de chay full  |
| Xu ly I/O + tham so dong lenh                                                             | Doc ghi SPMF trong [src/utils.jl](src/utils.jl); CLI tham so input/output/minsup/impl trong [src/cli.jl](src/cli.jl)                                               | Dat                                                 |

### Phan tich tung bac yeu cau

1. Cai dat co ban

- Nhom da cai dat thuat toan CHARM theo huong vertical tidset trong [src/algorithm/charm.jl](src/algorithm/charm.jl).
- Kieu du lieu ket qua duoc dong goi trong [src/structures.jl](src/structures.jl).
- Diem can ghi ro trong bao cao: phien ban hien tai la closed frequent itemset miner (CHARM), khong phai all frequent itemset miner.

2. Tai tao dung ket qua voi tham chieu SPMF

- Da co logic so sanh voi file tham chieu trong [tests/test_correctness.jl](tests/test_correctness.jl).
- Tuy nhien o code hien tai:
  - cac bo toy 1-5 dang duoc comment trong registry test,
  - mot so case benchmark co duong dan/ten file chua dong bo voi du lieu local,
  - parser input mac dinh parse Int nen file item dang chu can duoc ma hoa so truoc khi test reference.

=> Vi vay neu cham theo tieu chi auto-test >= 5 CSDL thi hien tai moi dat mot phan.

3. Toi uu bo nho va toc do

- Toi uu chinh: thay Set tidset bang BitVector tidset.
- Co so so sanh basic vs bitset va kiem tra speedup/reduction trong [tests/test_benchmark.jl](tests/test_benchmark.jl).
- Yeu cau do luong cai thien so voi ban co ban duoc dap ung o muc thiet ke test; ket qua con phu thuoc su san co cua benchmark files.

4. Xu ly dau vao/dau ra va CLI

- Input SPMF (space-separated) va output SPMF co #SUP duoc cai dat trong [src/utils.jl](src/utils.jl).
- CLI nhan cac tham so can thiet trong [src/cli.jl](src/cli.jl):
  - --input
  - --output
  - --minsup
  - --impl

### Lenh chay mau

```bash
julia --project=. src/cli.jl --input data/toy/toy1.txt --output results/toy1_out.txt --minsup 2 --impl bitset
```

## Ket luan Chuong 3 (theo hien trang code)

- Dat chac: moi truong Julia, from-scratch CHARM closed, I/O + CLI, backend toi uu bitset.
- Chua dat day du theo cau chu all frequent itemsets cua de bai.
- Tai tao ket qua theo unit test >= 5 CSDL hien tai dat mot phan do cau hinh test va du lieu tham chieu chua dong bo hoan toan.

# 3.4. Chuong 4 - Thuc nghiem va danh gia (theo code hien tai)

Phan nay duoc viet theo nguyen tac: chi ket luan nhung gi co bang chung truc tiep trong repo hien tai. Noi dung duoi day phan biet ro giua (i) ha tang thuc nghiem da duoc cai dat, (ii) du lieu tham chieu da co san trong workspace, va (iii) cac yeu cau cua de bai chua the bao cao so lieu day du o trang thai hien tai.

## 3.4.1. Tap du lieu benchmark

### Hien trang du lieu trong workspace

- Thu muc [data/benchmark](data/benchmark) hien co cac file:
  - `accidents.txt`
  - `mushrooms.txt`
  - `retail.txt`
  - `T10I4D1000.txt`
  - `T10I4D1000.dat`
- Trong do, co it nhat 4 dataset benchmark co the dung de thuc nghiem tren may hien tai: accidents, mushrooms, retail, T10I4D1000.
- Script tong hop [scripts/evaluate.jl](scripts/evaluate.jl) duoc thiet ke de doc toan bo benchmark trong thu muc nay va chay 6 nhom thuc nghiem bat buoc cua Chuong 4.

### Doi chieu voi danh sach dataset mau trong de bai

| Dataset de bai goi y | Trang thai trong workspace hien tai                    | Nhan xet                                                               |
| -------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| Chess                | Khong thay file trong [data/benchmark](data/benchmark) | Chua the lap lai dung kich ban benchmark cho chess tren may hien tai   |
| Mushroom             | Co `mushrooms.txt`                                     | Co the dung de thuc nghiem                                             |
| Retail               | Co `retail.txt`                                        | Co the dung de thuc nghiem                                             |
| Accidents            | Co `accidents.txt`                                     | Co the dung de thuc nghiem                                             |
| T10I4D100K           | Chua co dung file 100K; hien co `T10I4D1000.*`         | Moi co ban thu nho hon, khong trung hoan toan voi dataset de bai goi y |

### Nhan xet

- Neu xet rieng ve so luong file benchmark local, workspace hien tai dat nguong toi thieu 4 tap du lieu de thuc nghiem.
- Tuy nhien, thanh phan dataset chua khop hoan toan voi danh sach benchmark chuan ma de bai neu ra, vi thieu chess va chua co dung T10I4D100K.
- Vi vay trong bao cao can ghi ro: nhom da co ha tang de chay tren 4 dataset benchmark, nhung bo du lieu tren may hien tai la `accidents`, `mushrooms`, `retail`, `T10I4D1000`; khong nen trinh bay nhu da chay tren `chess` hay `T10I4D100K` neu chua bo sung file tuong ung.

## 3.4.2. Thuc nghiem bat buoc

### Tong quan kha nang ho tro tu code hien tai

- Script [scripts/evaluate.jl](scripts/evaluate.jl) da duoc to chuc thanh 6 nhom thuc nghiem tuong ung cac muc (a) den (f) cua de bai va xuat CSV ra thu muc `results/`.
- Hai implementation `:basic` va `:bitset` da co san trong [src/algorithm/charm.jl](src/algorithm/charm.jl), tao co so de so sanh toc do va bo nho.
- Ham doc/ghi SPMF trong [src/utils.jl](src/utils.jl) cho phep doi chieu ket qua voi output tham chieu tu SPMF.

### Bang doi chieu cac thuc nghiem bat buoc voi hien trang code

| Muc thuc nghiem                  | Ho tro trong code hien tai                                                                                                  | Bang chung                                        | Trang thai bao cao hien tai                                                       |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------- |
| (a) Correctness voi SPMF         | Co khung so sanh trong [tests/test_correctness.jl](tests/test_correctness.jl) va [scripts/evaluate.jl](scripts/evaluate.jl) | Doc file tham chieu SPMF va tinh ti le khop       | Dat o muc ha tang; chua du du lieu reference benchmark trong workspace            |
| (b) Runtime theo minsup          | Co trong [scripts/evaluate.jl](scripts/evaluate.jl)                                                                         | Ham `run_runtime_and_count` quet nhieu moc minsup | Dat o muc thiet ke; chua du file `spmf_times.csv` de ve doi chieu day du voi SPMF |
| (c) So luong itemset theo minsup | Co trong [scripts/evaluate.jl](scripts/evaluate.jl)                                                                         | File output `c_itemset_count_vs_minsup.csv`       | Dat o muc thiet ke                                                                |
| (d) Su dung bo nho               | Co trong [tests/test_benchmark.jl](tests/test_benchmark.jl) va [scripts/evaluate.jl](scripts/evaluate.jl)                   | So sanh `:basic` vs `:bitset`, do heap/RSS        | Dat o muc cai dat                                                                 |
| (e) Scalability                  | Co y tuong va ham rieng trong [scripts/evaluate.jl](scripts/evaluate.jl)                                                    | Tao subset 10%-100%                               | Dat mot phan; can chinh lai script de chay on dinh end-to-end                     |
| (f) Anh huong do dai giao dich   | Co trong [scripts/evaluate.jl](scripts/evaluate.jl)                                                                         | Sinh du lieu tong hop voi avg_len tang dan        | Dat o muc cai dat                                                                 |

### Phan tich tung thuc nghiem

1. Kiem tra tinh dung dan (Correctness)

- Phan test tu dong tai [tests/test_correctness.jl](tests/test_correctness.jl) so sanh ket qua CHARM voi file tham chieu SPMF theo tung dataset va minsup.
- Tuy nhien, thu muc [data/reference/spmf](data/reference/spmf) hien chi co cac file toy1-toy5; chua co file reference cho mushrooms, retail, accidents hay T10I4D1000.
- Do do, voi workspace hien tai, nhom moi chung minh duoc co che so sanh reference, chu chua du bang chung de bao cao ti le khop hoan toan tren cac benchmark lon.

2. Thoi gian chay theo minsup

- Ham `run_runtime_and_count` trong [scripts/evaluate.jl](scripts/evaluate.jl) da thiet ke viec quet 5-7 muc minsup cho tung dataset va xuat CSV phuc vu ve do thi.
- Script cung yeu cau file `data/reference/spmf/spmf_times.csv` chua thoi gian chay cua SPMF tren cung cac moc minsup.
- Trong workspace hien tai khong thay file nay, nen chua the bao cao do thi so sanh thoi gian giua cai dat nhom va SPMF mot cach day du.

3. So luong frequent/closed itemset theo minsup

- Ve mat ma nguon, script da co duong xuat `c_itemset_count_vs_minsup.csv`.
- Tuy nhien can ghi ro mot gioi han quan trong: ham `charm(...)` trong [src/algorithm/charm.jl](src/algorithm/charm.jl) hien tra ve `MiningResult(..., :closed, ...)`, tuc la ket qua dang duoc sinh ra la closed frequent itemsets.
- Vi vay, neu de bai yeu cau bieu do so luong all frequent itemsets theo minsup, thi bao cao hien tai chi co the trinh bay bieu do closed itemsets, khong nen ghi thanh all frequent itemsets.

4. Su dung bo nho

- So sanh bo nho giua `:basic` va `:bitset` da duoc cai dat ro rang trong [tests/test_benchmark.jl](tests/test_benchmark.jl) va phien ban tong quat hon trong [scripts/evaluate.jl](scripts/evaluate.jl).
- Huong toi uu chinh la thay tidset dang `Set{Int}` bang `BitVector`, phu hop voi ly thuyet giam chi phi giao va giam overhead cap phat.
- O muc bao cao hien tai, co the ket luan ve mat thiet ke rang ban `:bitset` la ban toi uu duoc nhom huong den; con so lieu peak RAM cu the van can chay script tren du lieu that.

5. Kha nang mo rong (Scalability)

- [scripts/evaluate.jl](scripts/evaluate.jl) da co ham rieng de tao cac tap con 10%, 25%, 50%, 75%, 100% giao dich.
- Tuy nhien, phan hien thuc nay chua that su san sang bao cao so lieu cuoi cung: trong ham `run_scalability`, bien `chosen` duoc lay tu danh sach dataset 3 thanh phan `(name, path, txns)` nhung sau do lai duoc unpack theo 2 bien, cho thay script can duoc chinh lai truoc khi chay end-to-end on dinh.
- Vi vay, o hien trang code, muc scalability nen duoc mo ta la da co khung thuc nghiem, chua nen dua bang/doi thi ket qua chinh thuc.

6. Anh huong cua do dai giao dich trung binh

- Ham `run_avglen_impact` trong [scripts/evaluate.jl](scripts/evaluate.jl) sinh du lieu tong hop voi do dai giao dich muc tieu 5, 10, 15, 20, 30 va do thoi gian cua ban `:bitset`.
- Day la thiet ke hop ly de minh hoa anh huong cua giao dich dai hon den chi phi intersection tidset va kich thuoc khong gian tim kiem.
- Tuy nhien, day van la thuc nghiem synthetic; workspace hien tai chua kem theo ket qua CSV da sinh, nen bao cao phan nay moi nen dung o muc mo ta quy trinh va ky vong ly thuyet.

### Ket luan muc 3.4.2

- Neu xet ve ma nguon, nhom da chuan bi gan nhu day du khung thuc nghiem cho ca 6 yeu cau bat buoc.
- Neu xet ve kha nang tai lap ket qua tren workspace hien tai, Chuong 4 chua o trang thai hoan tat do thieu reference benchmark SPMF, thieu file thoi gian `spmf_times.csv`, va mot vai diem chua dong bo trong script danh gia/test benchmark.
- Vi vay bao cao nen tach bach hai muc: `da cai dat ha tang thuc nghiem` va `chua du bang chung de cong bo so lieu day du tren 4 benchmark chuan + SPMF`.

## 3.4.3. Phan tich ket qua

### Nhung ket luan co the rut ra tu code hien tai

1. Diem manh

- Co hai backend `:basic` va `:bitset`, nen viec danh gia tac dong cua toi uu hoa ve toc do va bo nho la kha thi ngay tren cung mot codebase tai [src/algorithm/charm.jl](src/algorithm/charm.jl).
- Da co script danh gia tong hop [scripts/evaluate.jl](scripts/evaluate.jl) va test chuyen biet [tests/test_benchmark.jl](tests/test_benchmark.jl), cho thay nhom khong chi cai dat thuat toan ma con huong den danh gia thuc nghiem he thong.
- Da co cau truc de xuat CSV, tu do co the ve bieu do trong notebook bao cao sau khi bo sung du lieu tham chieu.

2. Diem yeu

- Ket qua hien tai la closed frequent itemsets, trong khi de bai mo ta theo huong all frequent itemsets. Day la sai khac ve muc tieu dau ra, anh huong truc tiep den cach dien giai cac bieu do so luong itemset va correctness voi SPMF.
- Du lieu reference benchmark va bang thoi gian SPMF chua du, nen cac nhan xet so sanh voi SPMF hien chua co nen tang so lieu day du.
- Mot so thanh phan benchmark chua dong bo voi du lieu local: [tests/test_benchmark.jl](tests/test_benchmark.jl) dang benchmark `chess`, nhung file nay khong co trong [data/benchmark](data/benchmark); script `evaluate.jl` ky vong `T10I4D100K` trong khi workspace chi co `T10I4D1000`.

3. Cach dien giai ket qua trong bao cao hien tai

- Khong nen viet theo huong `nhom da hoan thanh day du cac bieu do Chuong 4`.
- Nen viet theo huong `nhom da xay dung duoc bo khung thuc nghiem cho Chuong 4, trong do cac phep do correctness, runtime, memory, scalability va synthetic avg_len da co san o muc ma nguon; tuy nhien viec tong hop so lieu cuoi cung con phu thuoc vao benchmark/reference SPMF va mot vai dieu chinh nho de dong bo script`.
- Neu can nop bao cao ngay theo code hien tai, nen uu tien dua ra nhan xet ve mat thiet ke thuc nghiem va gioi han hien tai, thay vi dua cac con so cu the chua duoc tai lap tren workspace.

### Hai huong toi uu hoa cu the co the de xuat tiep

- Hoan thien pipeline danh gia Chuong 4: bo sung file reference SPMF cho 4 dataset benchmark, tao `spmf_times.csv`, dong bo ten dataset benchmark local, va sua cac diem chua khop trong [scripts/evaluate.jl](scripts/evaluate.jl) de co the sinh CSV/figure end-to-end.
- Mo rong thuat toan tu closed mode sang ho tro day du all frequent itemsets (hoac tach ro hai che do `all` va `closed`), tu do dap ung sat hon yeu cau de bai va lam cho cac bieu do correctness/count co y nghia dung voi de bai goc.

## Ket luan Chuong 4 (theo hien trang code)

- Workspace hien tai da co khung ma nguon cho toan bo 6 thuc nghiem bat buoc cua Chuong 4.
- Nhom co san it nhat 4 dataset benchmark local de thu nghiem, nhung thanh phan dataset chua khop hoan toan voi danh sach benchmark chuan de bai.
- Bao cao hien tai co the khang dinh manh ve mat thiet ke va kha nang tu dong hoa thuc nghiem; chua nen khang dinh da hoan tat day du so lieu so sanh voi SPMF tren 4 benchmark lon, vi reference/time files va mot vai diem dong bo script van con thieu.

# 3.5. Chuong 5 - Ung dung thuc te (Optional)

## 3.5.1. Bai toan chon: Market Basket Analysis

Nhom chon bai toan phan tich gio hang tren tap du lieu ban le thuc te `retail.txt`
trong thu muc `data/benchmark/`.

Muc tieu:

- Dung chinh cai dat CHARM cua nhom de tim frequent itemsets (khong dung thu vien FIM co san).
- Tu frequent itemsets, sinh association rules `X => Y` voi:
  - `sup(X U Y) >= minsup`
  - `conf(X => Y) >= minconf`
- Sap xep va trinh bay top-10 luat theo `lift`.

## 3.5.2. Cau hinh chay va quy trinh

Script thuc hien: `scripts/market_basket_rules.jl`.

Cau hinh da su dung cho ket qua ben duoi:

- Dataset: `data/benchmark/retail.txt`
- `minsup = 0.02` (tuong ung `1764/88166` giao dich)
- `minconf = 0.35`
- Implementation: `:bitset`

Quy trinh:

1. Doc transaction va ma hoa token item ve ID so nguyen de dua vao CHARM.
2. Chay CHARM de khai pha frequent closed itemsets.
3. Liet ke cac proper subset cua tung itemset de tao cap `(X, Y)` sao cho `X U Y = itemset`.
4. Tinh `support`, `confidence`, `lift`; loc theo minsup va minconf.
5. Sap xep giam dan theo lift, lay top-10 va ghi ra CSV.

File ket qua:

- `results/retail_top10_rules.csv`

## 3.5.3. Top-10 association rules theo lift

Bang duoi day duoc trich tu ket qua chay that tren may:

| Rank | Rule (X => Y)      | Support | Confidence | Lift   |
| ---- | ------------------ | ------- | ---------- | ------ |
| 1    | {37} => {39,40}    | 0.0221  | 0.6625     | 5.6459 |
| 2    | {171} => {39,40}   | 0.0229  | 0.6515     | 5.5525 |
| 3    | {40,171} => {39}   | 0.0229  | 0.9806     | 5.5433 |
| 4    | {171} => {39}      | 0.0344  | 0.9781     | 5.5291 |
| 5    | {111} => {39}      | 0.0309  | 0.9753     | 5.5135 |
| 6    | {37,40} => {39}    | 0.0221  | 0.9548     | 5.3978 |
| 7    | {37} => {39}       | 0.0316  | 0.9503     | 5.3720 |
| 8    | {90} => {40,49}    | 0.0241  | 0.5538     | 1.6755 |
| 9    | {40,90} => {49}    | 0.0241  | 0.7730     | 1.6175 |
| 10   | {39,42} => {40,49} | 0.0226  | 0.5109     | 1.5457 |

Nhan xet nhanh:

- Cac luat top dau co lift > 5, cho thay nhom item `{39,40}` va item `{39}` co
  tinh lien ket rat manh voi cac item tien de `{37}`, `{171}`, `{111}`.
- Nhieu luat co confidence rat cao (xap xi 0.95-0.98), nghia la khi thay tien de,
  kha nang xuat hien ve phai rat lon.

## 3.5.4. Dien giai y nghia kinh doanh

Do dataset retail dang an danh theo ID item, bao cao dien giai theo huong hanh vi dong mua:

1. Goi san pham bo tro (cross-sell bundle)

- Cac cap co lift cao nhu `{37} => {39,40}` hoac `{171} => {39,40}` goi y
  nen de xuat bo san pham di kem trong trang gio hang/checkout.

2. Toi uu bo tri ke hang

- Cac item co xu huong mua cung nhau (nhom 37-39-40-171) co the dat gan nhau
  de tang kha nang mua bo sung.

3. Khuyen mai theo dieu kien

- Vi du neu khach mua item 37 thi hien thi coupon/combo voi nhom item 39-40,
  uu tien cac luat co confidence cao de giam rui ro khuyen mai khong hieu qua.

4. Uu tien luat co support du lon

- Cac luat top-10 deu co support ~2.2%-3.4%, tuong ung hang ngan giao dich,
  nen co y nghia thuc tien (khong phai pattern qua hiem).

## 3.5.5. Luu y tuan thu de bai

- Tat ca ket qua tren duoc tao bang cai dat CHARM cua nhom trong repo nay.
- Khong dung output tu thu vien FIM co san de tao ket qua Chuong 5.
