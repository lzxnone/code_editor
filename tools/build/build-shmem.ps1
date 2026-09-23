# build-shmem.ps1 —— 为 Android 双架构构建 libandroid-shmem（SysV IPC 共享内存后端）
#
# 为什么需要：
#   proot 的 --sysvipc 在 Android 上用 libandroid-shmem 支撑 shmget/shmat。
#   该库上游用 __ANDROID_API__ >= 26 静态选择后端，但实测 Android 11+ 已不允许应用
#   进程打开 /dev/ashmem（EACCES），而 libandroid 的 ASharedMemory_*（memfd 支撑）可用。
#   tools/patches/libandroid-shmem-runtime-ashmem.patch 把选择改为运行时 dlsym：
#   现代设备走 ASharedMemory，老设备（API 24/25）回退 /dev/ashmem。
#
# 另外两个构建参数：
#   -D_PATH_TMP="<app cache>/"  ── 上游引用 bionic 未定义的 _PATH_TMP，
#                                  它是命名 shm key 的 symlink 存放位置
#   -Wno-implicit-function-declaration ── 上游漏了 <fcntl.h>（老 clang 只是警告）
#
# 用法：
#   pwsh tools\build\build-shmem.ps1 [-AppId com.example.code_editor] [-OutDir build_proot_out\shmem]

param(
    [string]$SrcDir = "build_proot_deps\libandroid-shmem",
    [string]$OutDir = "build_proot_out\shmem",
    [string]$AppId,
    [string[]]$Abis = @("arm64-v8a", "x86_64"),
    [string]$ApiLevel = "24"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$ndkBin = Get-ChildItem "D:\Android\SDK\ndk" -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin" } |
    Where-Object { Test-Path (Join-Path $_ "clang.exe") } |
    Select-Object -First 1
if (-not $ndkBin) { throw "找不到 NDK clang" }
$clang = Join-Path $ndkBin "clang.exe"
$readelf = Join-Path $ndkBin "llvm-readelf.exe"

# --- 源码与补丁 -----------------------------------------------------------
if (-not (Test-Path (Join-Path $SrcDir "shmem.c"))) {
    Write-Host "克隆 libandroid-shmem..." -ForegroundColor Cyan
    & git clone --depth 1 https://github.com/termux/libandroid-shmem.git $SrcDir
}
$patch = "tools\patches\libandroid-shmem-runtime-ashmem.patch"
if ((Test-Path $patch) -and -not (Select-String -Path (Join-Path $SrcDir "shmem.c") -Pattern "choose the ashmem backend at RUNTIME" -Quiet)) {
    Write-Host "应用运行时后端补丁..." -ForegroundColor Cyan
    & git -C $SrcDir apply (Resolve-Path $patch).Path
    if ($LASTEXITCODE -ne 0) { throw "补丁应用失败: $patch" }
}

# --- app id（决定 _PATH_TMP：命名 shm key 的 symlink 存放位置）-------------
if (-not $AppId) {
    $m = Select-String -Path "android\app\build.gradle.kts" -Pattern 'applicationId\s*=\s*"([^"]+)"' | Select-Object -First 1
    $AppId = if ($m) { $m.Matches.Groups[1].Value } else { "com.lzxnone.code_editor" }
}
$tmpDef = "-D_PATH_TMP=`"/data/data/$AppId/cache/`""
Write-Host "applicationId=$AppId  _PATH_TMP=/data/data/$AppId/cache/" -ForegroundColor Cyan

$triples = @{ "arm64-v8a" = "aarch64-linux-android$ApiLevel"; "x86_64" = "x86_64-linux-android$ApiLevel" }
$srcAbs = (Resolve-Path $SrcDir).Path
$outAbs = Join-Path $root $OutDir

foreach ($abi in $Abis) {
    if (-not $triples.ContainsKey($abi)) { throw "不支持的 ABI: $abi" }
    $target = $triples[$abi]
    $abiDir = Join-Path $outAbs $abi
    New-Item -ItemType Directory -Force -Path $abiDir | Out-Null
    $obj = Join-Path $abiDir "shmem.o"
    $so  = Join-Path $abiDir "libandroid-shmem.so"
    Write-Host "`n===== $abi ($target) =====" -ForegroundColor Green

    Push-Location $srcAbs
    $w = & $clang --target=$target -fpic -std=c11 -Wall -Wextra -Wno-implicit-function-declaration $tmpDef -c shmem.c -o $obj 2>&1
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc -ne 0) { throw "编译失败: $($w -join "`n")" }
    $warnings = $w | Select-String -Pattern "implicitly|undeclared"
    if ($warnings) { Write-Host "  （上游漏 include 的告警）: $(($warnings | Measure-Object).Count) 条" -ForegroundColor DarkYellow }

    Push-Location $srcAbs
    $linkOut = & $clang --target=$target "-Wl,--version-script=exports.txt" -shared $obj -o $so -llog 2>&1
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc -ne 0) { throw "链接失败: $($linkOut -join "`n")" }

    $needed = (& $readelf -d $so 2>&1 | Select-String -Pattern "NEEDED") |
        ForEach-Object { ($_.ToString() -split '\[|\]')[1] }
    Write-Host "  ✅ $so ($((Get-Item $so).Length) 字节)  NEEDED: $($needed -join ', ')" -ForegroundColor Green
}

Write-Host "`n完成。proot 构建时用：-ShmemLib $OutDir" -ForegroundColor Cyan
