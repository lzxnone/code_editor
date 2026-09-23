<div align="center">

<img src="assets/icon/app_icon.png" width="128" height="128" alt="LN Code Editor Logo" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.25);" />

# LN 代码编辑器 (LN Code Editor)

**专为 Android 打造的现代化、轻量级移动端代码编辑器与便携 IDE**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20(ARM64%20%7C%20ARM32%20%7C%20x86__64)-green.svg)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com)

[简体中文](README.md) | [English](README.md#english-summary)

</div>

---

## 📖 简介 (Introduction)

**LN 代码编辑器** 是一款专为 Android 移动平台深度打磨的高性能代码编辑工具与掌上轻量 IDE。针对触控屏幕交互进行了全方位优化，不仅具备多语言高亮、智能补全与语法纠错、可视化 Git 冲突解决器，更内置了**免 Root 的 Linux 容器与真实 Shell 终端环境**，让开发者随时随地在手机与平板上自如阅读、编写与调试代码。

---

## ✨ 核心特性 (Key Features)

### 1. 📝 专业级代码编辑体验
- **多语言语法高亮**：深度集成 `re_editor` 与 `re_highlight`，提供快速精准的语言词法着色。
- **智能补全与实时纠错**：
  - 变量、函数与关键词的实时自动补全提示。
  - 语法错误波浪线实时下划线与行号红黄指示点。
  - **总开关 + 补全/纠错双独立分开关**自由切换，满足纯净阅读与极速敲码不同场景。
- **自由缩放与排版**：双指手势自由缩放字体大小；内置 JetBrains Mono 与 Fira Code 等专业 Nerd Font 等宽字体。

### 2. 🌿 可视化 Git 冲突解决器
- **冲突区块智能识别**：自动检测文件中所有的 `<<<<<<<`、`=======`、`>>>>>>>` 冲突区块。
- **行内差异对比**：当前更改与传入更改高亮对比，一目了然。
- **快捷决策操作栏**：
  - *采用当前更改 (Accept Current)*
  - *采用传入更改 (Accept Incoming)*
  - *保留双方更改 (Accept Both)*
  - *无缝切入手动编辑 (Manual Edit)*
- **移动端适配优化**：防溢出横向平滑滚动条，操作时智能联动关闭下拉菜单与侧边栏。

### 3. 🐧 免 Root 内置 Linux 容器与终端
- **真实 Shell 环境**：基于 PRoot 技术深度封装轻量 Alpine Linux，无需 Root 即可获得原生 Linux 命令行能力。
- **流畅终端交互**：基于优化版 `xterm.dart` 与 `flutter_pty`，支持文本长按与手势框选、清晰字体排版与快捷键操作。
- **丰富的命令行生态**：可在安卓设备上直接使用 `git`、`apk`、`curl`、`python` 等命令行工具。

### 4. 🎨 瑞士极简主义设计
- 沉浸式暗黑主题，专注代码本身。
- 高对比度瑞士极简设计双色图标，完美适配 Android 8.0+ 自适应图标（Adaptive Icon）规范。

### 5. 🌐 完整国际化 (l10n)
- 原生支持简体中文（zh）与英文（en），跟随 Android 系统语言无缝切换。

---

## 🛠️ 技术栈与依赖架构

| 模块 | 技术选型 | 说明 |
| :--- | :--- | :--- |
| **基础框架** | Flutter 3.x / Dart 3.x | 高性能多端渲染引擎 |
| **核心编辑组件** | `re_editor` / `re_highlight` | 移动端高性能代码编辑与着色器 |
| **终端仿真** | `xterm` / `flutter_pty` | 终端框选优化、PTY 伪终端通信 |
| **容器沙箱** | PRoot + Alpine Linux / Shims | 原生 C/C++ 跨架构兼容层与动态环境 |
| **图标生成** | `flutter_launcher_icons` | 自动生成 Android 全套 Mipmap 及自适应图标 |
| **状态持久化** | `provider` / `shared_preferences` | 响应式状态管理与用户偏好持久化 |

---

## 🚀 下载安装与构建 (Installation & Build)

### 方式一：直接安装 Release APK (推荐)
本项目为不同机型提供了精准分包（已存放于 `releases/` 目录或 GitHub Releases）：

* **`LN-Code-Editor-<version>-arm64-v8a.apk`**（⭐ **绝大多数主流手机首选**，体积最小、运行最快）
* **`LN-Code-Editor-<version>-armeabi-v7a.apk`**（适配较早期的 32 位老旧设备）
* **`LN-Code-Editor-<version>-x86_64.apk`**（适配电脑端安卓模拟器、WSA 或 ChromeOS）
* **`LN-Code-Editor-<version>-universal.apk`**（全架构合一通用包）

### 方式二：从源码构建

#### 1. 前置环境要求
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24.0`)
- Android SDK (API 34) & NDK (`28.2.13676358`)
- JDK 11 或 17

#### 2. 拉取依赖并运行
```bash
# 获取依赖
flutter pub get

# 连接安卓手机或模拟器进行调试
flutter run
```

#### 3. 一键编译全架构 Release APK
工程内提供了一键自动化打包脚本：
```powershell
# Windows PowerShell
.\tools\build\build-release-apks.ps1
```
打包完成后，产物将自动按 `[软件名]-[版本号]-[架构].apk` 规范重命名并归档至 `releases/` 对应版本目录。

---

## 📁 目录结构

```text
├── android/               # Android 原生配置、JNI 库与 MethodChannel 通道实现
├── assets/                # 内置字体 (JetBrains/Fira)、Linux 镜像、图标等静态资产
│   ├── fonts/             # Nerd Font 编程等宽字体
│   ├── icon/              # 1024x1024 高清自适应应用图标
│   └── shims/             # 容器架构兼容层
├── lib/                   # Flutter / Dart 核心业务源码
│   ├── l10n/              # 国际化 Arb 文件 (中文/英文)
│   ├── models/            # 核心数据模型 (Git 冲突、文件结构等)
│   ├── providers/         # 状态管理 (编辑器设置、工作区等)
│   ├── services/          # 原生交互服务 (Linux Distro、执行器等)
│   ├── views/             # 核心视图 (编辑器主界面、补全管理、冲突页等)
│   └── widgets/           # 复用组件 (编辑区、Git 冲突面板、文件树)
├── packages/              # 经过定制与修复的第三方底层库 (re_editor, xterm)
├── tools/                 # 构建与检查脚本 (build-release-apks.ps1 等)
└── test/                  # 单元测试与 Widget 自动化测试用例
```

---

## 🧪 自动化测试

运行完整测试集：
```bash
flutter test
```

---

## 📄 开源许可证 (License)

本项目遵循 [MIT License](LICENSE) 协议开源。

---

<div id="english-summary"></div>

## 🌐 English Summary

**LN Code Editor** is a modern, lightweight, mobile-first code editor and portable IDE designed specifically for Android. Powered by Flutter, it delivers syntax highlighting, smart code completion & diagnostics, visual Git conflict resolution, and a **rootless integrated Linux container with a full PTY terminal**. Write, inspect, and run code right on your Android phone or tablet.
