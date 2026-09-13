# build-proot.ps1 —— 从 termux/proot 源码为 Android 双架构构建 proot
#
# 为什么需要这个脚本：proot 的构建入口是 src/GNUmakefile，它依赖 make/sh/awk/grep；
# 而本机没有这些工具（只有 NDK + git）。本脚本用 PowerShell 复刻 GNUmakefile 的全部
# 关键步骤，产物与「make -C src」一致：
#   1) 用 clang -E -dM 从 arch.h 提取 LOADER_ADDRESS / HAS_LOADER_32BIT / HAS_POKEDATA_WORKAROUND
#   2) 编译 .check_seccomp_filter / .check_process_vm 生成 build.h 的 HAVE_* 定义
#   3) 编译 65 个目标文件
#   4) 构建 loader（可执行体）→ strip → objcopy 成二进制块 → 链进 proot（loader 内嵌）
#   5) 若架构需要，生成并编译 loader-info.c（POKEDATA workaround 的符号偏移）
#   6) 链接成单个 libproot.so（ELF PIE 可执行体，NEEDED libtalloc.so）
#
# 用法：
#   pwsh tools\build\build-proot.ps1 -TallocInclude <含 talloc.h 的目录> [-Install]
#
# 说明：
#   - 不设 PROOT_UNBUNDLE_LOADER ⇒ loader 内嵌，产物是单个 .so（APK 无需额外文件）
#   - talloc：链接仓库里现成的 jniLibs/<abi>/libtalloc.so，只需要一个 talloc.h
#   - 32 位 loader（loader-m32）在我们的 64 位 rootfs 下用不到；源码头文件里它声明为
#     WEAK 符号，缺失不会导致链接失败。需要时用 -AlsoM32Loader 打开。

param(
    [string]$ProotSrc = "proot-source",
    [Parameter(Mandatory = $true)][string]$TallocInclude,
    [string]$TallocLibRoot = "android\app\src\main\jniLibs",
    [string]$OutDir = "build_proot_out",
    [string[]]$Abis = @("arm64-v8a", "x86_64"),
    # 可选：启用 SysV IPC 的共享内存后端（需要 libandroid-shmem）
    #   -ShmemLib build_proot_out\shmem   ← 该目录下每个 ABI 一个子目录，内含 libandroid-shmem.so
    # 打开后 proot 会 NEEDED libandroid-shmem.so；运行时是否真的启用由 --sysvipc 参数决定。
    [string]$ShmemLib,
    [switch]$AlsoM32Loader,
    [switch]$EnableProcessVm,
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

# --- 工具链 ---------------------------------------------------------------
$ndkBin = Get-ChildItem "D:\Android\SDK\ndk" -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin" } |
    Where-Object { Test-Path (Join-Path $_ "clang.exe") } |
    Select-Object -First 1
if (-not $ndkBin) { throw "找不到 NDK clang（期望 D:\Android\SDK\ndk\*\toolchains\llvm\prebuilt\windows-x86_64\bin）" }

$clang    = Join-Path $ndkBin "clang.exe"
$strip    = Join-Path $ndkBin "llvm-strip.exe"
$objcopy  = Join-Path $ndkBin "llvm-objcopy.exe"
$objdump  = Join-Path $ndkBin "llvm-objdump.exe"
$readelf  = Join-Path $ndkBin "llvm-readelf.exe"
$nm       = Join-Path $ndkBin "llvm-nm.exe"
foreach ($t in @($clang, $strip, $objcopy, $objdump, $readelf)) {
    if (-not (Test-Path $t)) { throw "缺少工具: $t" }
}

$srcDir = Join-Path $ProotSrc "src"
if (-not (Test-Path (Join-Path $srcDir "GNUmakefile"))) { throw "找不到 $srcDir\GNUmakefile" }
if (-not (Test-Path (Join-Path $TallocInclude "talloc.h"))) { throw "在 $TallocInclude 里找不到 talloc.h" }

# ABI → 目标三元组（64 位 / 32 位 loader 用）
$triples = @{
    "arm64-v8a" = @{ t64 = "aarch64-linux-android24"; t32 = "armv7a-linux-androideabi24" }
    "x86_64"    = @{ t64 = "x86_64-linux-android24";  t32 = "i686-linux-android24" }
}

# --- 从 GNUmakefile 解析目标文件列表（保持与上游同步）--------------------
function Get-ObjectList([string]$mkPath) {
    # 逐行解析 OBJECTS += 块（不依赖换行符风格，Windows 检出的 CRLF 也适用）
    $objs = @()
    $inBlock = $false
    foreach ($line in Get-Content $mkPath) {
        if ($line -match '^\s*OBJECTS \+=') { $inBlock = $true; continue }
        if ($inBlock -and $line -match '^\S') { break }   # 缩进结束 => 块结束
        if ($inBlock -and ($line -match '([A-Za-z0-9_/-]+)\.o')) { $objs += $Matches[1] }
    }
    if ($objs.Count -eq 0) { throw "无法从 GNUmakefile 解析 OBJECTS 列表（$mkPath）" }
    $objs | Sort-Object -Unique
}

# --- 从 arch.h 提取宏（等价于 GNUmakefile 的 define_from_arch.h）----------
function Get-ArchMacro([string]$target, [string]$name) {
    $out = & $clang "--target=$target" -E -dM -DNO_LIBC_HEADER (Join-Path $srcDir "arch.h") 2>$null
    $line = $out | Select-String -Pattern "\b$name\b" | Select-Object -First 1
    if (-not $line) { return $null }
    # 形如: #define LOADER_ADDRESS 0x600000000000
    $parts = ($line.ToString() -split '\s+')
    if ($parts.Count -ge 3) { return ($parts[2..($parts.Count - 1)] -join ' ') } else { return $null }
}

function Invoke-Compile([string]$target, [string]$source, [string]$output, [string[]]$extra) {
    # -Wno-implicit-function-declaration：上游个别文件（如 extension/ashmem_memfd）漏了
    # <string.h>，老 clang 只是警告，现代 clang 默认按错误处理；降级以保持与上游行为一致。
    $args = @("--target=$target", "-D_FILE_OFFSET_BITS=64", "-D_GNU_SOURCE", "-I.", "-I$srcDir",
              "-Wall", "-Wextra", "-O2", "-DARG_MAX=131072",
              "-Wno-implicit-function-declaration", "-I$TallocInclude") + $extra +
            @("-c", $source, "-o", $output)
    $out = & $clang @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "编译失败: $source`n$($out -join "`n")" }
}

# --- 主流程 ---------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$objectList = Get-ObjectList (Join-Path $srcDir "GNUmakefile")
Write-Host "从 GNUmakefile 解析到 $($objectList.Count) 个目标文件" -ForegroundColor Cyan

$version = (& git -C $ProotSrc describe --tags --dirty --abbrev=8 --always 2>$null)
if (-not $version) { $version = "unknown" }

foreach ($abi in $Abis) {
    if (-not $triples.ContainsKey($abi)) { throw "不支持的 ABI: $abi" }
    $t64 = $triples[$abi].t64
    $objDir = Join-Path $OutDir $abi
    New-Item -ItemType Directory -Force -Path $objDir | Out-Null
    Write-Host "`n===== 构建 $abi ($t64) =====" -ForegroundColor Green

    # 1) 架构宏
    $loaderAddr   = Get-ArchMacro $t64 "LOADER_ADDRESS"
    $loaderCflags = Get-ArchMacro $t64 "LOADER_ARCH_CFLAGS"
    $hasM32       = Get-ArchMacro $t64 "HAS_LOADER_32BIT"
    $hasPokedata  = Get-ArchMacro $t64 "HAS_POKEDATA_WORKAROUND"
    Write-Host "  LOADER_ADDRESS=$loaderAddr  LOADER_ARCH_CFLAGS='$loaderCflags'  32bit=$hasM32  pokedata=$hasPokedata"

    # 2) build.h（VERSION + HAVE_*，HAVE_ 由链接探测决定）
    $checkDir = Join-Path $objDir "check"
    New-Item -ItemType Directory -Force -Path $checkDir | Out-Null
    $defines = @()
    # HAVE_PROCESS_VM 默认**不开启**：PRoot 用它读写 tracee 内存，而 Android 应用进程策略
    # 可能拒绝 process_vm_readv/writev；现有可用的 2018 二进制也是 process_vm=no
    # （走 POKEDATA 兼容路径）。需要试验时加 -EnableProcessVm。
    $checks = @([pscustomobject]@{ file = "seccomp_filter"; define = "HAVE_SECCOMP_FILTER" })
    if ($EnableProcessVm) { $checks += [pscustomobject]@{ file = "process_vm"; define = "HAVE_PROCESS_VM" } }
    foreach ($c in $checks) {
        $exe = Join-Path $checkDir $c.file
        $null = & $clang "--target=$t64" "-o" $exe (Join-Path $srcDir ".check_$($c.file).c") 2>&1
        if ($LASTEXITCODE -eq 0) { $defines += "#define $($c.define) 1" ; Write-Host "  $($c.define) = 有" }
        else { Write-Host "  $($c.define) = 无（走兼容路径，符合预期）" }
    }
    if (-not $EnableProcessVm) { Write-Host "  HAVE_PROCESS_VM = 强制关闭（与现有可用二进制一致，走 POKEDATA 路径）" }
    $buildH = Join-Path $srcDir "build.h"
    @("#undef VERSION", "#define VERSION `"$version`"") + $defines | Set-Content -Path $buildH -Encoding ASCII
    Write-Host "  已生成 build.h (VERSION=$version)"

    # 3) 编译目标文件
    #    -ShmemLib 时给所有目标文件加 WITH_LIBANDROID_SHMEM（sysvipc 的 shm 后端改用
    #    libandroid-shmem 的 shmget/shmat 实现；不传 --sysvipc 时该扩展不激活）
    $objDefs = @()
    if ($ShmemLib) { $objDefs += "-DWITH_LIBANDROID_SHMEM" }
    $objects = @()
    $i = 0
    foreach ($o in $objectList) {
        $i++
        $cFile = Join-Path $srcDir "$o.c"
        $oFile = Join-Path $objDir ("{0}.o" -f ($o -replace '/', '_'))
        Invoke-Compile $t64 $cFile $oFile $objDefs
        $objects += $oFile
    }
    Write-Host "  已编译 $i 个目标文件"

    # 4) loader（内嵌形态）：编 → 链 → （保留未 strip 副本供 readelf）→ strip → objcopy 成二进制块
    $loaderObjDir = Join-Path $objDir "loader"
    New-Item -ItemType Directory -Force -Path $loaderObjDir | Out-Null
    $loaderC   = Join-Path $srcDir "loader\loader.c"
    $loaderAsm = Join-Path $srcDir "loader\assembly.S"
    $loaderLo  = Join-Path $loaderObjDir "loader.o"
    $loaderSo  = Join-Path $loaderObjDir "assembly.o"
    $loaderRaw = Join-Path $loaderObjDir "loader"           # 未 strip（上游 .INTERMEDIATE）
    $loaderBin = Join-Path $loaderObjDir "loader.exe"       # strip 后（用于 objcopy 包装）
    $loaderWrap = Join-Path $loaderObjDir "loader-wrapped.o"
    $extraL = @("-fPIC", "-ffreestanding")
    if ($loaderCflags) { $extraL += ($loaderCflags -split '\s+') }
    Invoke-Compile $t64 $loaderC $loaderLo $extraL
    $null = & $clang "--target=$t64" "-fPIC" "-c" $loaderAsm "-o" $loaderSo 2>&1
    if ($LASTEXITCODE -ne 0) { throw "loader/assembly.S 编译失败" }
    $ldArgs = @("--target=$t64", "-static", "-nostdlib",
                "-Wl,--build-id=none", "-Wl,-Ttext=$loaderAddr", "-Wl,-z,noexecstack",
                "-o", $loaderRaw, $loaderLo, $loaderSo)
    $null = & $clang @ldArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "loader 链接失败" }
    Copy-Item $loaderRaw $loaderBin -Force
    & $strip $loaderBin 2>&1 | Out-Null
    # 由 objdump -f 推 objcopy 需要的 --output-target / --binary-architecture
    $f = (& $objdump -f $loaderSo 2>&1 | Select-String -Pattern "file format|architecture" | Select-Object -First 2)
    $fmt  = ($f[0].ToString() -replace '.*file format\s+', '').Trim()
    $arch = ($f[1].ToString() -replace '.*architecture:\s+', '').Trim()
    if (-not $fmt) { $fmt = if ($abi -eq "arm64-v8a") { "elf64-littleaarch64" } else { "elf64-x86-64" } }
    if (-not $arch) { $arch = if ($abi -eq "arm64-v8a") { "aarch64" } else { "i386:x86-64" } }
    # objcopy 生成的符号名由**传入的文件名**决定（须为裸文件名，否则会变成
    # _binary_<路径>_start，与 enter.c 期望的 _binary_loader_exe_start 不符）⇒ 在 loader 目录内执行
    Push-Location $loaderObjDir
    $null = & $objcopy --input-target=binary "--output-target=$fmt" "--binary-architecture=$arch" "loader.exe" "loader-wrapped.o" 2>&1
    $objcopyRc = $LASTEXITCODE
    Pop-Location
    if ($objcopyRc -ne 0) { throw "objcopy 包装 loader 失败 (fmt=$fmt arch=$arch)" }
    $objects += $loaderWrap
    Write-Host "  loader 内嵌就绪（$((Get-Item $loaderBin).Length) 字节，objcopy fmt=$fmt arch=$arch）"

    # 5) POKEDATA workaround：由 **未 strip 的** loader 符号表生成 loader-info.c（复刻 loader-info.awk）
    if ($hasPokedata -eq "true") {
        $syms = & $readelf -s $loaderRaw 2>&1
        $pw = $null; $st = $null
        foreach ($line in $syms) {
            $t = ($line.ToString().Trim() -split '\s+')
            if ($t.Count -lt 3) { continue }
            $name = $t[-1]
            $val  = $t[1]
            if ($val -notmatch '^[0-9a-fA-F]+$') { continue }
            if ($name -eq 'pokedata_workaround') { $pw = [Convert]::ToInt64($val, 16) }
            elseif ($name -eq '_start') { $st = [Convert]::ToInt64($val, 16) }
        }
        if ($null -eq $pw -or $null -eq $st) { throw "无法从未 strip 的 loader 提取 pokedata_workaround / _start" }
        $infoC = Join-Path $srcDir "loader\loader-info.c"
        @("#include <unistd.h>", "const ssize_t offset_to_pokedata_workaround=$($pw - $st);") |
            Set-Content -Path $infoC -Encoding ASCII
        $infoO = Join-Path $loaderObjDir "loader-info.o"
        Invoke-Compile $t64 $infoC $infoO @()
        $objects += $infoO
        Write-Host "  loader-info.c 已生成 (offset=$($pw - $st))"
    }

    # 6) 链接 proot（单个自包含 .so；NEEDED libtalloc.so[+ libandroid-shmem.so]）
    $tallocDir = Join-Path $TallocLibRoot $abi
    if (-not (Test-Path (Join-Path $tallocDir "libtalloc.so"))) {
        throw "找不到 $tallocDir\libtalloc.so（用于链接）"
    }
    $libArgs = @("-L$tallocDir", "-ltalloc")
    if ($ShmemLib) {
        $shmemDir = Join-Path $ShmemLib $abi
        if (-not (Test-Path (Join-Path $shmemDir "libandroid-shmem.so"))) {
            throw "找不到 $shmemDir\libandroid-shmem.so（-ShmemLib 需要每个 ABI 一个子目录）"
        }
        $libArgs += @("-L$shmemDir", "-landroid-shmem")
    }
    $outSo = Join-Path $objDir "libproot.so"
    $linkArgs = @("--target=$t64", "-o", $outSo) + $objects + $libArgs + @("-Wl,-z,noexecstack")
    $out = & $clang @linkArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "链接 libproot.so 失败`n$($out -join "`n")" }
    $null = & $strip $outSo 2>&1
    $size = (Get-Item $outSo).Length
    $needed = & $readelf -d $outSo 2>&1 | Select-String -Pattern "NEEDED|SONAME"
    Write-Host "  ✅ 产出 $outSo ($size 字节)$(if ($ShmemLib) { '  [含 libandroid-shmem 后端]' })" -ForegroundColor Green
    Write-Host "     $(($needed | ForEach-Object { $_.ToString().Trim() }) -join ' | ')"
}

# --- 可选：安装到 jniLibs（覆盖前备份）-----------------------------------
if ($Install) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    foreach ($abi in $Abis) {
        $built = Join-Path (Join-Path $OutDir $abi) "libproot.so"
        if (-not (Test-Path $built)) { continue }
        $target = Join-Path (Join-Path $TallocLibRoot $abi) "libproot.so"
        if (Test-Path $target) { Copy-Item $target "$target.bak-$stamp" -Force }
        Copy-Item $built $target -Force
        Write-Host "已安装 $target（旧文件备份为 libproot.so.bak-$stamp）" -ForegroundColor Yellow
    }
}

Write-Host "`n完成。产物在 $OutDir\<abi>\libproot.so" -ForegroundColor Cyan
