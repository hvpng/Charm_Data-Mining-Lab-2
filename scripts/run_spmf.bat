@echo off
REM ============================================================
REM  scripts/run_spmf.bat
REM  Chạy SPMF CHARM trên tất cả dataset x minsup points
REM  Kết quả lưu vào data/reference/spmf/
REM
REM  Yêu cầu:
REM    - Java đã cài (kiểm tra: java -version)
REM    - spmf.jar đặt ở thư mục gốc repo (cùng chỗ README.md)
REM    - Các file .txt dataset đặt trong data\benchmark\
REM
REM  Cách chạy (từ thư mục gốc repo):
REM    scripts\run_spmf.bat
REM ============================================================

setlocal enabledelayedexpansion

REM ── Đường dẫn ────────────────────────────────────────────────
set SPMF=spmf.jar
set INDIR=data\benchmark
set OUTDIR=data\reference\spmf
set INDIRTOY=data\toy

REM ── Tạo thư mục output nếu chưa có ──────────────────────────
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

REM ── Kiểm tra spmf.jar ────────────────────────────────────────
if not exist "%SPMF%" (
    echo [LỖI] Không tìm thấy %SPMF%
    echo Hãy tải spmf.jar từ:
    echo   https://www.philippe-fournier-viger.com/spmf/spmf.jar
    echo Đặt vào thư mục gốc repo rồi chạy lại.
    pause
    exit /b 1
)

REM ── Kiểm tra Java ────────────────────────────────────────────
java -version >nul 2>&1
if errorlevel 1 (
    echo [LỖI] Java chưa được cài đặt hoặc chưa có trong PATH.
    echo Tải Java tại: https://adoptium.net
    pause
    exit /b 1
)

REM ============================================================
REM  Danh sách dataset và minsup points tương ứng
REM
REM  Giải thích cách chọn minsup:
REM    - chess, mushrooms : dataset dày đặc → minsup cao (20-80%)
REM    - retail          : dataset thưa    → minsup thấp (0.5-5%)
REM    - accidents       : dataset lớn/dày → minsup cao (20-80%)
REM    - T10I4D100K      : dataset thưa    → minsup thấp (0.5-5%)
REM
REM  Dùng đúng các minsup này trong evaluate.jl để kết quả khớp.
REM ============================================================


REM ── toy1 ────────────────────────────────────────────────────
if exist "%INDIRTOY%\toy1.txt" (
    echo.
    echo [toy1]
    set "MINSUP=0.4"
    echo   MINSUP=0.4 ...
    java -jar %SPMF% run Charm_bitset %INDIRTOY%\toy1.txt %OUTDIR%\toy1_minsup%%40.txt !MINSUP!
    echo   -^> %OUTDIR%\toy1_minsup%%40.txt
) else (
    echo [SKIP] toy1.txt không tồn tại trong %INDIRTOY%\
)

REM ── toy2 ────────────────────────────────────────────────────
if exist "%INDIRTOY%\toy2.txt" (
    echo.
    echo [toy2]
    set "MINSUP=0.4"
    echo   MINSUP=0.4 ...
    java -jar %SPMF% run Charm_bitset %INDIRTOY%\toy2.txt %OUTDIR%\toy2_minsup%%40.txt !MINSUP!
    echo   -^> %OUTDIR%\toy2_minsup%%40.txt
) else (
    echo [SKIP] toy2.txt không tồn tại trong %INDIRTOY%\
)

REM ── toy3 ────────────────────────────────────────────────────
if exist "%INDIRTOY%\toy3.txt" (
    echo.
    echo [toy3]
    set "MINSUP=0.4"
    echo   MINSUP=0.4 ...
    java -jar %SPMF% run Charm_bitset %INDIRTOY%\toy3.txt %OUTDIR%\toy3_minsup%%40.txt !MINSUP!
    echo   -^> %OUTDIR%\toy3_minsup%%40.txt
) else (
    echo [SKIP] toy3.txt không tồn tại trong %INDIRTOY%\
)

REM ── toy4 ────────────────────────────────────────────────────
if exist "%INDIRTOY%\toy4.txt" (
    echo.
    echo [toy4]
    set "MINSUP=0.4"
    echo   MINSUP=0.4 ...
    java -jar %SPMF% run Charm_bitset %INDIRTOY%\toy4.txt %OUTDIR%\toy4_minsup%%40.txt !MINSUP!
    echo   -^> %OUTDIR%\toy4_minsup%%40.txt
) else (
    echo [SKIP] toy4.txt không tồn tại trong %INDIRTOY%\
)

REM ── toy5 ────────────────────────────────────────────────────
if exist "%INDIRTOY%\toy5.txt" (
    echo.
    echo [toy5]
    set "MINSUP=0.4"
    echo   MINSUP=0.4 ...
    java -jar %SPMF% run Charm_bitset %INDIRTOY%\toy5.txt %OUTDIR%\toy5_minsup%%40.txt !MINSUP!
    echo   -^> %OUTDIR%\toy5_minsup%%40.txt
) else (
    echo [SKIP] toy5.txt không tồn tại trong %INDIRTOY%\
)

@REM echo ============================================================
@REM echo  Bắt đầu chạy SPMF CHARM
@REM echo  Input : %INDIR%\
@REM echo  Output: %OUTDIR%\
@REM echo ============================================================


@REM REM ── chess ────────────────────────────────────────────────────
@REM if exist "%INDIR%\chess.txt" (
@REM     echo.
@REM     echo [chess]
@REM     for %%M in (80 70 60 50 40 30 20) do (
@REM         set "MINSUP=%%M%%"
@REM         echo   minsup=%%M%% ...
@REM         java -jar %SPMF% run Charm_bitset %INDIR%\chess.txt %OUTDIR%\chess_minsup%%M.txt !MINSUP!
@REM         echo   -^> %OUTDIR%\chess_minsup%%M.txt
@REM     )
@REM ) else (
@REM     echo [SKIP] chess.txt không tồn tại trong %INDIR%\
@REM )

@REM REM ── mushroom ─────────────────────────────────────────────────
@REM if exist "%INDIR%\mushrooms.txt" (
@REM     echo.
@REM     echo [mushroom]
@REM     for %%M in (50 40 30 20 15 10 5) do (
@REM         set "MINSUP=%%M%%"
@REM         echo   minsup=%%M%% ...
@REM         java -jar %SPMF% run Charm_bitset %INDIR%\mushrooms.txt %OUTDIR%\mushroom_minsup%%M.txt !MINSUP!
@REM         echo   -^> %OUTDIR%\mushroom_minsup%%M.txt
@REM     )
@REM ) else (
@REM     echo [SKIP] mushrooms.txt không tồn tại trong %INDIR%\
@REM )

@REM REM ── retail ───────────────────────────────────────────────────
@REM if exist "%INDIR%\retail.txt" (
@REM     echo.
@REM     echo [retail]
@REM     for %%M in (5 4 3 2 1) do (
@REM         set "MINSUP=%%M%%"
@REM         echo   minsup=%%M%% ...
@REM         java -jar %SPMF% run Charm_bitset %INDIR%\retail.txt %OUTDIR%\retail_minsup%%M.txt !MINSUP!
@REM         echo   -^> %OUTDIR%\retail_minsup%%M.txt
@REM     )
@REM ) else (
@REM     echo [SKIP] retail.txt không tồn tại trong %INDIR%\
@REM )

@REM REM ── accidents ────────────────────────────────────────────────
@REM if exist "%INDIR%\accidents.txt" (
@REM     echo.
@REM     echo [accidents]
@REM     for %%M in (80 70 60 50 40 30 20) do (
@REM         set "MINSUP=%%M%%"
@REM         echo   minsup=%%M%% ...
@REM         java -jar %SPMF% run Charm_bitset %INDIR%\accidents.txt %OUTDIR%\accidents_minsup%%M.txt !MINSUP!
@REM         echo   -^> %OUTDIR%\accidents_minsup%%M.txt
@REM     )
@REM ) else (
@REM     echo [SKIP] accidents.txt không tồn tại trong %INDIR%\
@REM )

@REM REM ── T10I4D100K ───────────────────────────────────────────────
@REM if exist "%INDIR%\T10I4D100K.txt" (
@REM     echo.
@REM     echo [T10I4D100K]
@REM     for %%M in (5 4 3 2 1) do (
@REM         set "MINSUP=%%M%%"
@REM         echo   minsup=%%M%% ...
@REM         java -jar %SPMF% run Charm_bitset %INDIR%\T10I4D100K.txt %OUTDIR%\T10I4D100K_minsup%%M.txt !MINSUP!
@REM         echo   -^> %OUTDIR%\T10I4D100K_minsup%%M.txt
@REM     )
@REM ) else (
@REM     echo [SKIP] T10I4D100K.txt không tồn tại trong %INDIR%\
@REM )

echo.
echo ============================================================
echo  Hoàn thành! File reference lưu trong: %OUTDIR%\
echo  Tiếp theo: chạy julia --project=. scripts/evaluate.jl
echo ============================================================
pause