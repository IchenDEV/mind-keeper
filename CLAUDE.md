# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mind Keeper is a macOS 26+ menu bar application that monitors system notifications and uses AI to automatically classify and prioritize tasks. It features a Liquid Glass design language and learns from user actions to improve prioritization.

## Build Commands

```bash
# Generate Xcode project (required after any project.yml changes)
xcodegen generate

# Open in Xcode
open MindKeeper.xcodeproj

# Build (Cmd+B in Xcode)
```

Requirements: Xcode 17+, XcodeGen, macOS 26+ Tahoe

## Architecture

The app follows a service-oriented architecture with clear separation:

### Core Flow
1. **NotificationMonitor** (actor) - Polls macOS notification database (`~/Library/Group Containers/group.com.apple.usernoted/db2/db`) every 4 seconds via SQLite3
2. **LLMService** (actor) - Classifies notifications using Ollama (primary) with CloudLLMProvider fallback, then OpenAI/Claude API
3. **PriorityEngine** (actor) - Computes priority scores using multi-factor scoring: urgency (30%), importance (25%), context boost (15%), memory adjustment (10%), freshness decay (10%), keyword boost (5%), frequency penalty (5%)
4. **AppCoordinator** - Orchestrates services, loads persisted tasks, manages timers
5. **AppState** - Observable state container for UI bindings

### Data Models (SwiftData)
- **TaskItem** - Core task with title, body, category, urgency, importance, priority, status (pending/completed/dropped/deferred/aging/expired/archived)
- **NotificationRecord** - Parsed notification from system DB
- **UserMemory** - Stores learned user preferences from actions

### Views (SwiftUI + Liquid Glass)
- **PopoverRoot** - Main popover container with panel switching
- **CardStackView** - Swipeable task cards (up=complete, left=defer, right=drop)
- **AddTaskView** - Manual task entry
- **SettingsView** - Ollama endpoint, cloud API key, preferences
- **OnboardingView** - First-launch setup
- **CleanupView** - Expired task management

## Key Patterns

- **@Observable macro** for state management (Swift 6)
- **SwiftData @Model** for persistence
- **Actor isolation** for async services (LLMService, PriorityEngine, NotificationMonitor)
- **Service injection** via AppCoordinator init
- **MemoryStore** builds context from UserMemory to improve LLM classification over time

## Important Notes

- App requires **Full Disk Access** permission to read system notification database
- It's a **menu bar only app** (LSUIElement=true) - no dock icon
- Priority scores range 0-10, sorted descending
- Tasks expire based on `ExpiryManager` rules (aging → expired after threshold)
- LLM classification returns: category, urgency, importance, reason, suggested_action
