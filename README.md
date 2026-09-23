<div align="center">

<img src="assets/icon/app_icon.png" width="128" height="128" alt="LN Code Editor Logo" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.25);" />

# LN 代码编辑器 (LN Code Editor)

**专为移动端打造的现代化、轻量级代码编辑器与便携 IDE**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com)

[简体中文](README.md) | [English](README.md#english-summary)

</div>

---

## 📖 简介 (Introduction)

**LN 代码编辑器** 是一款基于 Flutter 与原生技术深度打造的跨平台代码编辑工具与轻量 IDE。针对移动端触摸交互进行了深度体验优化，集成了多语言语法高亮、代码智能补全与语法纠错、可视化 Git 冲突解决，以及**免 Root 的内置 Linux 容器与真实终端环境**，让开发者能够在手机和平板上随时随地阅读、编辑与调试项目源码。

---

## ✨ 核心特性 (Key Features)

### 1. 📝 专业级代码编辑体验
- **多语言语法高亮**：深度集成 `re_editor` 与 `re_highlight`，提供快速且精准的语言着色。
- **智能补全与实时纠错**：
  - 支持函数、变量与关键字的实时自动补全。
  - 语法错误实时波浪线提示与行号警示点。
  - 提供**总控开关 + 补全/纠错双独立分开关**，由开发者自由定制。
- **自由缩放与排版**：双指自然缩放手势，字体大小自由调节；内置 JetBrains Mono 与 Fira Code 等专业 Nerd Font 等宽字体。

### 2. 🌿 可视化 Git 冲突解决器
- **冲突区块智能解析**：自动识别 `<<<<<<<`、`=======`、`>>>>>>>` 冲突标记。
- **差异可视化对比**：行内差异智能高亮显示，当前分支与传入更改一目了然。
- **一键快捷决策**：
  - *采用当前更改 (Accept Current)*
  - *采用传入更改 (Accept Incoming)*
  - *保留双方更改 (Accept Both)*
  - *无缝切入手动编辑 (Manual Edit)*
- **移动端适配优化**：防溢出横向平滑操作栏，自动智能管理侧边栏与弹窗生命周期。

### 3. 🐧 免 Root 内置 Linux 容器与终端
- **真实 Shell 环境**：基于 PRoot 技术深度封装轻量 Alpine Linux，无需 Root 即可获得原生 Linux 命令行能力。
- **流畅终端交互**：基于优化版 `xterm.dart` 与 `flutter_pty`，支持手势框选文本、清晰字体排版与快捷键操作。
- **命令行生态**：可在移动端直接体验 `git`、`apk`、`curl`、`python` 等常用命令行生态。

### 4. 🎨 瑞士极简主义设计
- 沉浸式暗黑主题，专注代码本身。
- 极简高对比度品牌标识，完美适配各大系统自适应图标（Adaptive Icon）规范。

### 5. 🌐 全平台与国际化支持
- **多语言 (i18n / l10n)**：内置简体中文与英文多语言支持，跟随系统语言无缝切换。
- **跨端架构**：主打 Android，同时支持 Windows、macOS、Linux 及 Web 平台。

---

## 🛠️ 技术栈与依赖架构

| 模块 | 技术选型 | 说明 |
| :--- | :--- | :--- |
| **基础框架** | Flutter 3.x / Dart 3.x | 高性能多端渲染引擎 |
| **核心编辑组件** | `re_editor` / `re_highlight` | 移动端高性能代码编辑与着色器 |
| **终端仿真** | `xterm` / `flutter_pty` | 终端框选优化、PTY 伪终端通信 |
| **容器沙箱** | PRoot + Alpine Linux / Shims | 原生 C/C++ 跨架构兼容层与动态环境 |
| **图标与资源** | `flutter_launcher_icons` | 工业级自适应全平台图标生成方案 |
| **状态与持久化** | `provider` / `shared_preferences` | 响应式状态管理与用户偏好持久化 |

---

## 🚀 快速上手 (Getting Started)

### 方式一：直接安装成品 (Release APK)
前往 [GitHub Releases](https://github.com) 页面，下载最新的 `app-release.apk`，在安卓手机上点击即可直接安装体验。

### 方式二：从源码构建运行

#### 1. 前置环境要求
- 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install) (推荐 `>= 3.24.0`)
- 安装 Android SDK 与 NDK (`28.2.13676358`)
- JDK 11 / 17

#### 2. 克隆项目与拉取依赖
```bash
# 克隆仓库
git clone https://github.com/your-username/code_editor.git
cd code_editor

# 安装 Flutter 依赖包
flutter pub get
```

#### 3. 启动调试
```bash
# 启动连接的设备（手机或模拟器）
flutter run
```

#### 4. 打包 Release 成品
```bash
# 打包通用 Android Release APK
flutter build apk --release

# 或者打包 64 位极简版（体积缩小 50%）
flutter build apk --split-per-abi --release
```
编译产物位于：`build/app/outputs/flutter-apk/`

---

## 📁 目录结构简析

```text
├── android/               # Android 原生配置与 MethodChannel 通道实现
├── assets/                # 内置字体 (JetBrains/Fira)、Linux 镜像、图标等静态资产
│   ├── fonts/             # Nerd Font 编程字体
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
└── test/                  # 单元测试与 Widget 自动化测试用例
```

---

## 🧪 自动化测试

运行项目的完整单元测试与 Widget 交互测试集：
```bash
flutter test
```

---

## 🤝 参与贡献 (Contributing)

我们非常欢迎社区的 Issue 与 PR！
1. Fork 本仓库并新建分支 (如 `feature/amazing-feature`)；
2. 提交您的修改 (`git commit -m 'feat: Add some amazing feature'`)；
3. 推送至您的分支 (`git push origin feature/amazing-feature`)；
4. 提交 Pull Request。

---

## 📄 开源许可证 (License)

本项目遵循 [MIT License](LICENSE) 协议开源。

---

<div id="english-summary"></div>

## 🌐 English Summary

**LN Code Editor** is a modern, lightweight, mobile-first code editor and portable IDE powered by Flutter. Designed for optimal touchscreen productivity, it brings together syntax highlighting, smart code completion & diagnostics, visual Git conflict resolution, and a **rootless integrated Linux container with a full PTY terminal**. Write, inspect, and run code anywhere, right on your Android phone or tablet.
