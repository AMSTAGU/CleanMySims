# CleanMySims UI Redesign - Design Document

Date: 2026-02-17
Status: Validated

## Overview

Refonte complète de l'interface de CleanMySims avec un style "Zen Minimal" - flat design épuré avec couleurs pastel.

## Design Principles

- **Flat design** : Pas d'effets de verre, blur, ou ombres prononcées
- **Minimaliste** : Beaucoup d'espace, lignes fines, éléments épurés
- **Pastel doux** : Palette de couleurs douces et apaisantes
- **Immersif** : Fenêtre sans barre de titre, boutons système natifs conservés

---

## 1. Window Specifications

| Property | Value |
|----------|-------|
| Dimensions | 800 x 550 px |
| Resizable | No (fixed) |
| Title bar | Hidden (immersive) |
| Traffic lights | Native macOS (red/yellow/green) |
| Background | Off-white `#FAFAFA` |

---

## 2. Color Palette

### Base Colors

| Element | Color | Hex |
|---------|-------|-----|
| Main background | Off-white | `#FAFAFA` |
| Sidebar background | Light gray | `#F5F5F5` |
| Primary text | Anthracite gray | `#2D2D2D` |
| Secondary text | Medium gray | `#6B6B6B` |
| Border/Subtle | Very light gray | `#E5E5E5` |
| Hover background | Light gray | `#EEEEEE` |

### Category Accent Colors (Pastel)

| Category | Color | Hex |
|----------|-------|-----|
| Caches | Sky blue | `#A8D8EA` |
| Simulators | Powder pink | `#F8B4B4` |
| Runtimes | Mint | `#B5EAD7` |
| Builds | Peach | `#FFDAC1` |
| Device Support | Lavender | `#C7CEEA` |

### Semantic Colors

| Usage | Color | Hex |
|-------|-------|-----|
| Danger/Delete | Soft coral | `#E88B8B` |
| Success | Sage green | `#A8D5BA` |

---

## 3. Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Main title (total size) | SF Pro | 32pt | Light |
| Section headers | SF Pro | 16pt | Medium |
| Body text | SF Pro | 13pt | Regular |
| Labels/Captions | SF Pro | 11pt | Regular |
| Monospace (sizes) | SF Mono | 11pt | Regular |

---

## 4. Custom Sidebar

### Specifications

- Width: 200px
- Background: `#F5F5F5`
- No native styling

### Structure

```
┌────────────────────┐
│ CleanMySims        │  ← Header (14pt, medium)
│                    │
│ Dashboard          │  ← Section "Général"
│                    │
│ ─────────────────  │  ← Separator (1px gray)
│                    │
│ 📦 Caches      ?   │
│ 📱 Simulators  ?   │  ← Section "Catégories"
│ ⚙️ Runtimes    ?   │    Each with icon + label + ?
│ 🔨 Builds      ?   │
│ 📲 Support     ?   │
│                    │
└────────────────────┘
```

### Item Styling

- Height: 40px
- Horizontal padding: 16px
- Icon: 18px, category accent color
- Label: 13pt, `#2D2D2D`
- Help icon `?`: 12px, `#6B6B6B`, right-aligned
- Hover: background `#EEEEEE`
- Selected: light tint of category color + 3px left border in category color

### Help Tooltips

- Trigger: Hover on `?` (300ms delay)
- Background: White with subtle shadow
- Max width: 200px
- Font: 11pt

**Tooltip Content:**

| Category | Help Text |
|----------|-----------|
| Caches | "Données temporaires des simulateurs : logs, caches de compilation, données téléchargées" |
| Simulators | "Les appareils virtuels iOS utilisés par Xcode pour tester vos apps" |
| Runtimes | "Les versions d'iOS installées pour faire tourner les simulateurs" |
| Builds | "Données de compilation générées par Xcode (DerivedData)" |
| Device Support | "Fichiers de support pour connecter des iPhone/iPad physiques à Xcode" |

---

## 5. Dashboard View

### Header

- "Espace récupérable" label: 13pt, `#6B6B6B`
- Total size: 32pt, SF Light, `#2D2D2D`
- Centered horizontally
- Padding top: 40px

### Category Cards Grid

- Layout: 2 columns
- Gap: 16px
- Horizontal padding: 32px
- Distribution: 2 + 2 + 1 (last centered) OR 2 + 3 if space allows

### Card Styling

```
┌─────────────────────┐
│  📦            ?    │
│                     │
│  Caches             │
│  4.2 GB             │
└─────────────────────┘
```

- Background: White `#FFFFFF`
- Border: 1px `#E5E5E5`
- Border-radius: 12px
- Padding: 20px
- Hover: subtle shadow + scale(1.02)

### Card Content

- Icon: 24px, category accent color, top-left
- Help `?`: 12px, top-right (same tooltip system)
- Category name: 15pt, medium, bottom-left
- Size: 13pt, `#6B6B6B`, below name

### Action

- Click navigates to detail view for that category

### Footer

- Single "Rescan" button, centered
- Style: white background, gray border, dark gray text, 13pt
- Padding: 24px bottom

---

## 6. Detail List View

### Header Bar

```
┌─────────────────────────────────────────────────────┐
│ Caches                    Sort [v]    4.2 GB  [🗑 Clean]
├─────────────────────────────────────────────────────┤
```

- Title: 16pt, medium, left
- Total size: 16pt, category accent color, right
- Sort dropdown: small, gray
- Clean button: coral background, white text
- Padding: 16px horizontal, 12px vertical
- Bottom border: 1px `#E5E5E5`

### List Rows

```
┌─────────────────────────────────────────────────────┐
│ iPhone 15 Pro - iOS 17.2                      [📂][🗑]│
│ iOS 17.2 • ~/Library/.../iPhone 15 Pro    2.1 GB    │
├─────────────────────────────────────────────────────┤
```

- Row height: 56px
- Horizontal padding: 16px
- Separator: 1px `#EEEEEE`
- Background: transparent (shows main background)

### Row Content

- Line 1: Item name (13pt, medium, `#2D2D2D`)
- Line 2: Additional info + truncated path (11pt, `#6B6B6B`)
- Size: 11pt mono, right-aligned
- Action buttons: appear on hover
  - Folder icon: `#A8D8EA`, "Open in Finder"
  - Trash icon: `#E88B8B`, "Delete"

### Empty State

- Large checkmark icon: 48px, `#A8D5BA`
- Text: "Tout est propre !" (16pt, `#6B6B6B`)

---

## 7. Loading Animations

### Scan Animation

- **Overlay**: Content visible at 50% opacity (no blur/black)
- **Progress bar**:
  - Centered (300px × 4px)
  - Background: `#E5E5E5`
  - Fill: Gradient of all pastel accent colors
  - Border-radius: 2px
- **Text**: "Scan en cours..." (13pt, `#6B6B6B`), below bar
- **End transition**: 0.3s fade out, numeric animation on sizes

### Clean Animation

- Same structure as scan
- **Progress bar fill**:
  - Starts: Coral `#E88B8B`
  - Ends: Sage green `#A8D5BA`
- **Text**: "Nettoyage en cours..." then "Terminé !"
- **Completion**: Show "X GB libérés !" for 1.5s, then return to normal view

---

## 8. Dialogs

### Delete Confirmation

```
┌─────────────────────────────────┐
│                                 │
│  Supprimer cet élément ?        │
│                                 │
│  "iPhone 15 Pro - iOS 17.2"     │
│  2.1 GB seront libérés.         │
│                                 │
│     [Annuler]    [Supprimer]    │
│                                 │
└─────────────────────────────────┘
```

- Background: White
- Border-radius: 12px
- Subtle shadow
- "Annuler": Text only, gray
- "Supprimer": Coral background `#E88B8B`, white text

### Clean Category Confirmation

Same style, adapted text:
- Title: "Nettoyer les [Catégorie] ?"
- Detail: "X éléments, Y GB seront supprimés"
- Buttons: [Annuler] [Nettoyer]

---

## Files to Modify/Create

### Modified Files

1. `Theme.swift` - Complete color and typography overhaul
2. `ContentView.swift` - Window setup, immersive mode
3. `SidebarView.swift` - Custom flat sidebar
4. `DashboardView.swift` - New card grid, remove Clean All
5. `DetailListView.swift` - Updated styling
6. `ScanningView.swift` - Replace with progress bar

### New Files

1. `Views/Components/MinimalCard.swift` - Flat category card
2. `Views/Components/HelpIcon.swift` - Reusable ? with tooltip
3. `Views/Components/ProgressBar.swift` - Simple progress bar
4. `Views/Components/ConfirmDialog.swift` - Confirmation dialog

---

## Summary of Changes from Current UI

| Current | New |
|---------|-----|
| Glassmorphism (blur, Material) | Flat design (solid colors) |
| Dark theme | Light theme (off-white) |
| Vibrant accent colors | Pastel accent colors |
| Pulsing circles scan animation | Simple progress bar |
| "Clean All" button | Removed (per-category only) |
| Native sidebar | Custom flat sidebar |
| Scrollable dashboard | Fixed window, no scroll needed |
| No help system | ? icons with tooltips |
