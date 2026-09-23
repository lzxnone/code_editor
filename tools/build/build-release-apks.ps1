# tools/build/build-release-apks.ps1
# 一键编译全架构 Android Release APK 并按规范重命名

param (
    [string]$AppEngName = "LN-Code-Editor",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

# 如果未指定版本号，自动从 pubspec.yaml 读取
if (-not $Version) {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match "version:\s*([^\+\r\n]+)") {
        $Version = "v" + $matches[1].Trim()
    } else {
        $Version = "v1.0.0"
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 🚀 正在构建 $AppEngName $Version Android 多架构 Release APK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 执行分架构构建
Write-Host "`n[1/2] 正在编译分架构 APK (arm64-v8a / armeabi-v7a / x86_64)..." -ForegroundColor Yellow
flutter build apk --split-per-abi --release

# 2. 执行全架构通用包构建
Write-Host "`n[2/2] 正在编译全架构通用 APK (Universal)..." -ForegroundColor Yellow
flutter build apk --release

# 3. 规范化重命名并归档至 releases/ 目录
$outputDir = "releases\$Version"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" -Destination "$outputDir\$AppEngName-$Version-arm64-v8a.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" -Destination "$outputDir\$AppEngName-$Version-armeabi-v7a.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-x86_64-release.apk" -Destination "$outputDir\$AppEngName-$Version-x86_64.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "$outputDir\$AppEngName-$Version-universal.apk" -Force

Write-Host "`n🎉 构建成功！产物已归档至目录: $outputDir" -ForegroundColor Green
Get-ChildItem -Path $outputDir | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB, 2)}}, LastWriteTime | Format-Table -AutoSize
