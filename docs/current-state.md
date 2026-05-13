# Current State

## Project Status
Casalist is currently in an early functional prototype stage inside Xcode.

The app is being built as a native iOS application using:
- SwiftUI
- SwiftData
- CloudKit

The current focus is building core household management functionality before refining advanced UI, automation, or AI features.

---

# Implemented Features

## App Foundation

### CasalistApp.swift
- App entry point is configured
- Database/container initialization exists
- CloudKit syncing support has been started

### Data Model
A task-based data structure currently exists.

The app currently supports:
- Task titles
- Categories
- Assignees
- Point values
- Grocery-related task handling

---

# User Interface

## Dashboard / Home Screen
A main dashboard screen currently exists.

The dashboard acts as the central hub for:
- Viewing household tasks
- Navigating to feature areas
- Creating new tasks

---

## Task Creation
A task creation flow currently exists.

Features implemented:
- Add task form
- Category selection
- Assignee selection
- Point calculation logic

Current point behavior:
- Chores award points
- Grocery items do not award points

---

## Personal Task View
A filtered personal task screen currently exists.

Implemented behavior:
- Displays tasks assigned to a specific family member
- Uses filtering logic to separate personal tasks from all household tasks

---

## Grocery List
A grocery list view currently exists.

Implemented behavior:
- Grocery items can be separated from normal chores/tasks
- Grocery-related tasks dynamically appear in the grocery section

---

# Design Direction

Current design goals:
- Native iOS appearance
- SwiftUI-first architecture
- SF Symbols usage
- Simple family-friendly layouts
- Minimal complexity during MVP phase

---

# Architecture Notes

Current architecture direction:
- Modular SwiftUI views
- Shared task data model
- CloudKit-backed syncing
- iOS-first development approach

---

# Known Missing Features

The following features are planned but not yet fully implemented:
- Family scheduling/calendar
- Notifications/reminders
- Recurring tasks
- User profiles/settings
- Advanced dashboard analytics
- Widgets
- AI/chat features
- Apple Watch support

---

# Development Priorities

Current priorities:
1. Stabilize core task functionality
2. Improve dashboard UI
3. Improve navigation structure
4. Refine CloudKit syncing
5. Expand household organization tools