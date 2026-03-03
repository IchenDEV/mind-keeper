<div align="center">

# 🧠 Mind Keeper

**AI-Powered Notification Triage for macOS**

[![macOS](https://img.shields.io/badge/macOS-26+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-0D96F6?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-2E7D32)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-000000?logo=apple)](https://www.apple.com/macos/)

[![Ollama](https://img.shields.io/badge/Ollama-Local%20AI-FF6B35?logo=ollama&logoColor=white)](https://ollama.com)
[![OpenAI](https://img.shields.io/badge/OpenAI-Compatible-412991?logo=openai&logoColor=white)](https://openai.com)
[![Claude](https://img.shields.io/badge/Claude-Compatible-D4A574?logo=anthropic&logoColor=white)](https://anthropic.com)

<p align="center">
  <b>English</b> | <a href="#中文">中文</a>
</p>

<img src="https://img.shields.io/badge/Status-Active%20Development-00C853?style=for-the-badge" alt="Status">
<img src="https://img.shields.io/badge/Architecture-Actor%20Model-7B1FA2?style=for-the-badge" alt="Architecture">
<img src="https://img.shields.io/badge/Data-SwiftData%20%2B%20SQLite-0288D1?style=for-the-badge" alt="Data">

</div>

---

## ✨ Features

<table>
<tr>
<td width="50%">

- 🔔 **Smart Notification Monitoring**
  Auto-poll macOS Notification Center database every 4s

- 🤖 **AI Classification**
  Local Ollama first, cloud API fallback

- ⚡ **Intelligent Prioritization**
  Multi-factor scoring: urgency, importance, context, freshness

- 👆 **Gesture Controls**
  Swipe up → Complete | Left → Defer | Right → Drop

</td>
<td width="50%">

- ✏️ **Manual Tasks**
  Add custom tasks alongside notifications

- 🧠 **Adaptive Learning**
  Learns from your actions to improve suggestions

- 🗂️ **Auto-Cleanup**
  Expired tasks batch management

- 🎨 **Liquid Glass Design**
  Native macOS 26 visual language

</td>
</tr>
</table>

---

## 🚀 Quick Start

### Prerequisites

- macOS 26 Tahoe or later
- [Xcode 17+](https://developer.apple.com/xcode/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [Ollama](https://ollama.ai) (for local AI)

### Installation

```bash
# Install XcodeGen
brew install xcodegen

# Install Ollama and pull a model
brew install ollama
ollama pull llama3.2

# Clone and setup
git clone https://github.com/yourusername/mind-keeper.git
cd mind-keeper
xcodegen generate

# Build and run
open MindKeeper.xcodeproj
```

### Required Permissions

Mind Keeper requires **Full Disk Access** to read the system notification database:

```
System Settings → Privacy & Security → Full Disk Access → Add Mind Keeper
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  NotificationMonitor (Actor)                                  │
│  └─→ Polls ~/Library/Group Containers/.../db2/db (SQLite3)  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LLMService (Actor)                                          │
│  ├─→ OllamaProvider (Primary)                               │
│  └─→ CloudLLMProvider (Fallback: OpenAI/Claude)             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PriorityEngine (Actor)                                      │
│  └─→ Multi-factor scoring (urgency 30%, importance 25%...)  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  AppState (@Observable)                                      │
│  └─→ SwiftData persistence + UI bindings                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

<div align="center">

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 |
| UI Framework | SwiftUI (Liquid Glass) |
| Persistence | SwiftData |
| Notifications | SQLite3 |
| Local AI | Ollama |
| Cloud AI | OpenAI / Claude API |

</div>

---

## 📁 Project Structure

```
MindKeeper/
├── App/
│   ├── MindKeeperApp.swift      # App entry point (MenuBarExtra)
│   ├── AppState.swift           # Observable state container
│   └── AppCoordinator.swift     # Service orchestration
├── Views/
│   ├── PopoverRoot.swift        # Main popover container
│   ├── CardStackView.swift      # Swipeable task cards
│   ├── AddTaskView.swift        # Manual task entry
│   ├── SettingsView.swift       # Preferences & API keys
│   └── CleanupView.swift        # Expired task management
├── Models/
│   ├── TaskItem.swift           # SwiftData @Model
│   ├── NotificationRecord.swift # Parsed notification
│   └── UserMemory.swift         # Learning data
├── Services/
│   ├── NotificationMonitor.swift # SQLite polling
│   ├── LLMService.swift         # AI classification
│   ├── PriorityEngine.swift     # Scoring algorithm
│   ├── MemoryStore.swift        # User behavior learning
│   └── ExpiryManager.swift      # Task lifecycle
└── Resources/
    ├── Info.plist
    ├── MindKeeper.entitlements
    └── Assets.xcassets
```

---

---

<div align="center">

# 🧠 Mind Keeper

**macOS 智能通知调度助手**

<p align="center">
  <a href="#english">English</a> | <b>中文</b>
</p>

</div>

## ✨ 功能特性

<table>
<tr>
<td width="50%">

- 🔔 **智能通知监听**
  每 4 秒自动轮询 macOS 通知中心数据库

- 🤖 **AI 智能分类**
  本地 Ollama 优先，云端 API 无缝回退

- ⚡ **多因子优先级**
  紧急度、重要性、上下文、时效性综合评分

- 👆 **手势交互**
  上滑完成 | 左滑延迟 | 右滑丢弃

</td>
<td width="50%">

- ✏️ **手动任务**
  支持添加自定义任务

- 🧠 **自适应学习**
  根据操作习惯持续优化推荐

- 🗂️ **自动清理**
  过期任务批量管理

- 🎨 **Liquid Glass 设计**
  原生 macOS 26 设计语言

</td>
</tr>
</table>

---

## 🚀 快速开始

### 前置要求

- macOS 26 Tahoe 或更高版本
- [Xcode 17+](https://developer.apple.com/xcode/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [Ollama](https://ollama.ai) (本地 AI 引擎)

### 安装步骤

```bash
# 安装 XcodeGen
brew install xcodegen

# 安装 Ollama 并拉取模型
brew install ollama
ollama pull llama3.2

# 克隆并设置项目
git clone https://github.com/yourusername/mind-keeper.git
cd mind-keeper
xcodegen generate

# 构建并运行
open MindKeeper.xcodeproj
```

### 必要权限

Mind Keeper 需要**完全磁盘访问权限**来读取系统通知数据库：

```
系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Mind Keeper
```

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│  NotificationMonitor (Actor)                                  │
│  └─→ 轮询 ~/Library/Group Containers/.../db2/db (SQLite3)   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LLMService (Actor)                                          │
│  ├─→ OllamaProvider (主引擎)                                │
│  └─→ CloudLLMProvider (备用: OpenAI/Claude)                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PriorityEngine (Actor)                                      │
│  └─→ 多因子评分 (紧急度30%, 重要性25%...)                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  AppState (@Observable)                                      │
│  └─→ SwiftData 持久化 + UI 绑定                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 技术栈

<div align="center">

| 层级 | 技术 |
|------|------|
| 编程语言 | Swift 6 |
| UI 框架 | SwiftUI (Liquid Glass) |
| 数据持久化 | SwiftData |
| 通知读取 | SQLite3 |
| 本地 AI | Ollama |
| 云端 AI | OpenAI / Claude API |

</div>

---

## 📄 License

[MIT](LICENSE) © 2025 Mind Keeper Contributors

<div align="center">

Made with ❤️ on macOS

[![Stars](https://img.shields.io/github/stars/yourusername/mind-keeper?style=social)](https://github.com/yourusername/mind-keeper)
[![Forks](https://img.shields.io/github/forks/yourusername/mind-keeper?style=social)](https://github.com/yourusername/mind-keeper)

</div>
