---
name: Care Log Minimalist
colors:
  surface: '#fafaf5'
  surface-dim: '#dadad5'
  surface-bright: '#fafaf5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f4ef'
  surface-container: '#eeeee9'
  surface-container-high: '#e8e8e4'
  surface-container-highest: '#e2e3de'
  on-surface: '#1a1c19'
  on-surface-variant: '#434844'
  inverse-surface: '#2f312e'
  inverse-on-surface: '#f1f1ec'
  outline: '#737874'
  outline-variant: '#c3c8c3'
  surface-tint: '#56615a'
  primary: '#1a241f'
  on-primary: '#ffffff'
  primary-container: '#2f3a34'
  on-primary-container: '#98a49c'
  inverse-primary: '#bdc9c1'
  secondary: '#57615a'
  on-secondary: '#ffffff'
  secondary-container: '#d8e2da'
  on-secondary-container: '#5b655e'
  tertiary: '#2d1e1e'
  on-tertiary: '#ffffff'
  tertiary-container: '#443333'
  on-tertiary-container: '#b39b9a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d9e6dd'
  primary-fixed-dim: '#bdc9c1'
  on-primary-fixed: '#131e19'
  on-primary-fixed-variant: '#3e4943'
  secondary-fixed: '#dbe5dd'
  secondary-fixed-dim: '#bfc9c1'
  on-secondary-fixed: '#151e18'
  on-secondary-fixed-variant: '#3f4943'
  tertiary-fixed: '#f7dcdc'
  tertiary-fixed-dim: '#dac1c0'
  on-tertiary-fixed: '#261818'
  on-tertiary-fixed-variant: '#554242'
  background: '#fafaf5'
  on-background: '#1a1c19'
  surface-variant: '#e2e3de'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  vital-display:
    fontFamily: Inter
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-md-bold:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.005em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: -0.005em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-compact: 0.5rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system is engineered for front-line caregivers in severe disability residential facilities. The environment demands high data density, rapid input-output cycles, and zero visual cognitive fatigue during night shifts or emergency triage.

The aesthetic fuses **Utilitarian Minimalism** with **Calming Institutional Warmth**. Instead of cold, sterile hospital whites or playful consumer pastel gradients, the system utilizes deeply grounded forest neutrals and warm off-white bases. Every pixel serves legibility, speed, and trust. 

- **Audience**: Professional disability care workers, nurses, and social workers moving between beds, medication trays, and shift changeovers.
- **Tone & Mood**: Resolute, steady, warm, and highly structured.
- **Visual Principle**: No artificial glowing neon, no non-semantic decoration. High physical-touch target ergonomics with dense, tabulated visual hierarchy.

## Colors

The palette is anchored by `#2F3A34` (Deep Forest Slate), providing authority and grounding contrast without the harshness of pure black. The canvas base `#F7F7F2` softens screen glare in low-light residential rooms.

### Text & Neutral Tokens
- **Background / Canvas**: `#F7F7F2` (Warm Sand Mist)
- **Surface Layer 1**: `#FFFFFF` (Card container fill)
- **Surface Layer 2**: `#EFEFE8` (Recessed wells, secondary pills)
- **Border Subtle**: `#E2E4DC`
- **Border Default**: `#CDD2CB`
- **Text Primary**: `#2B2F2C` (Charcoal Slate)
- **Text Secondary**: `#4D554F` (Mid Forest Smoke)
- **Text Tertiary**: `#707A73` (Muted Label Slate)

### 5-Tier Vital Condition Status Tokens
All 5-stage health indicators must combine background, border, text color, and mandatory text + symbol labeling to ensure immediate universal recognition:
- **Normal (`평소`)**: Text `#4C7D62`, Bg `#E9F3ED`, Border `#75AA8D` — Symbol `✓`
- **Caution (`주의`)**: Text `#8A5D12`, Bg `#FBF1DD`, Border `#D9A44E` — Symbol `!`
- **Abnormal (`이상`)**: Text `#9A4F12`, Bg `#FCEBDC`, Border `#D9853B` — Symbol `▲`
- **Danger (`위험`)**: Text `#A8403F`, Bg `#FBEAEA`, Border `#DC8584` — Symbol `⚠`
- **Low (`저온`)**: Text `#3F6EA0`, Bg `#E8F0FA`, Border `#6A9ED5` — Symbol `▼`

### Facility Unit / Room Identifiers
- **Aquarius (`물병자리`)**: `#A89AC2`
- **Pisces (`물고기자리`)**: `#7FA8C4`
- **Ursa (`곰자리`)**: `#B59A7A`
- **Milky Way (`은하수자리`)**: `#87A98E`
- **Aries (`양자리`)**: `#D39B94`
- **Cetus (`고래자리`)**: `#7D9BB0`

## Typography

Typography focuses on immediate optical recognition across Korean system typefaces (Pretendard, Apple SD Gothic Neo, Kakao Sans) and Inter fallback.

### Rules & Formatting
- **Tabular Figures**: Every numeric display (vital numbers, body temperatures, military timestamps, shift counts) must enforce `font-feature-settings: "tnum" 1` or `font-variant-numeric: tabular-nums` to eliminate layout jitter during scrolling and real-time refreshes.
- **Metric Contrast**: Measured vital numbers use `vital-display` (30px Bold) paired with unit labels in `body-sm` (13px Regular) aligned to the baseline.
- **Tracking**: Strict negative letter-spacing between `-0.01em` and `-0.02em` throughout Korean and Latin characters for compact readability.

## Layout & Spacing

The structural baseline is optimized for modern mobile displays (default base width: 390px) with density tuned to Level 7. Caregivers must parse lists without excessive vertical travel while maintaining thumb-reach ergonomics.

### Layout Principles
- **Root Margin**: `16px` (`margin`: `1rem`) on horizontal viewport edges.
- **Card Gutter**: `12px` (`gutter`: `0.75rem`) vertical stacking distance between resident logs.
- **Touch Ergonomics**: All interactive elements (status selection pills, temperature adjustment steppers, quick notes) strictly adhere to a `min-height` and `min-width` of `44px`.
- **Content Stacking**: Tight metadata pairs (e.g., resident name + age + room) use `space-xs` (4px), while intra-card section boundaries use `space-md` (12px).

## Elevation & Depth

To avoid optical clutter and preserve battery life under sustained mobile operation, the design system minimizes heavy drop shadows in favor of **structural containment and low-contrast borders**.

### Depth Layers
- **Level 0 (Canvas Base)**: `#F7F7F2` flat background.
- **Level 1 (Card Container)**: Solid `#FFFFFF` fill with `1px solid #E2E4DC`. No blur shadow; clarity is defined by surface contrast.
- **Level 2 (Active/Pressed Card & Floating Controls)**: `#FFFFFF` with `0px 2px 8px rgba(47, 58, 52, 0.08)` and `1px solid #CDD2CB`.
- **Level 3 (Modal / Bottom Sheet)**: Surface `#FFFFFF` with `0px -4px 20px rgba(43, 47, 44, 0.12)`, anchored by a 40% opacity backdrop curtain (`rgba(43, 47, 44, 0.40)`).
- **No Gloss / No Skeuomorphic Glow**: Avoid simulated neon inner shadows, glass blur diffusion, or saturated artificial gradients.

## Shapes

The roundedness language balances structural order with approachable warmth. 

- **Primary Cards**: `14px` border radius (`rounded-lg` equivalent).
- **Badges & Status Chips**: `6px` to `8px` corner radius for structured tag appearance.
- **Floating Action Buttons & Quick Dial**: `9999px` circular geometry to distinctly separate utility actions from standard reading lists.
- **Form Inputs & Search**: `10px` radius for distinct, quiet boundaries.

## Components

### 1. Navigation Shell & Primary Action
- **Three-Tab Bottom Bar**:
  - `[인수인계]` (Handover / Log): Left navigation tab.
  - `[일정]` (Schedule / Care Plan): Right navigation tab.
  - Height: `64px` + device safe-area-inset. Background: `#FFFFFF` with `1px top border #E2E4DC`. Active icon/label color: `#2F3A34`; inactive: `#707A73`.
- **Center Quick Dial Trigger (`◉ 퀵 체온`)**:
  - A prominent elevated circular button (`56px` diameter) centered in the bottom dock, overlapping the bar edge.
  - Background: Primary `#2F3A34`, foreground icon/text `#FFFFFF`.
  - Tap interaction triggers a rapid-entry radial or sheet dial to log resident temperature in under 3 seconds.

### 2. Status Chips & Vital Indicators
- **Rule**: Every health evaluation chip must display both the icon, text label, and background/border combination.
- **Dimensions**: Height `28px`, horizontal padding `8px`, corner radius `6px`, font `label-md`.
- **Border**: `1px solid` matching the respective condition token border.

### 3. Resident Card (Care Item)
- **Surface**: White `#FFFFFF`, border `1px solid #E2E4DC`, corner radius `14px`, padding `14px 16px`.
- **Header**: Resident Room Pill (`10px` circle or colored text tag matching the Class colors, e.g., `#A89AC2` for Aquarius) + Resident Name (`headline-sm`, `#2B2F2C`) + Age/Gender (`body-sm`, `#707A73`).
- **Vital Display Area**: Large bold temperature reading (`vital-display`, tabular numerals) + 5-stage status badge (`✓ 평소 36.5°C`).
- **Footer**: Last measured time (`tabular-nums`, `#707A73`) + care note excerpt (`body-sm`, `#4D554F`).

### 4. Emergency / Danger Banner (`위험`)
- Full-bleed or inset banner using the Danger token pair: Background `#FBEAEA`, border `#DC8584`, text `#A8403F`.
- Contains leading alert glyph `⚠`, resident name, temperature, and immediate action trigger (`의사 호출` / `재측정`).

### 5. Form Elements & Toggles
- **Numeric Stepper / Quick Temp Presets**: Pre-populated buttons (`36.5`, `37.0`, `37.5`, `38.0`) with minimum tap target `44px x 44px`. Default state has `#EFEFE8` fill; selected state has `#2F3A34` fill with `#FFFFFF` text.
- **Checkboxes & Radios**: `20px` footprint wrapped in a `44px` invisible tap target. Check fill `#2F3A34` with white tick mark.