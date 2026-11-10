# Frontend Components — U05 Scan Library

Inputs: `mockups.md` and `mockups.html` (screens 1 and 4), `interaction-spec.md`, `accessibility-checklist.md`, `stories.md` (US-10).

## Library (screen 1) — `LibraryView`, `LibraryModel`

| Part | Behaviour |
|---|---|
| Top bar | Diagnostics (leading) and Explore (trailing), unchanged. Title "Scans". |
| Scan row | Thumbnail (56 pt), name (up to two lines), "Method · 11 Nov · 4.8 MB", green seal tick only when `hasAccuracyReport` (labelled "Has an accuracy report"). Tap opens Scan detail. |
| Swipe | Trailing swipe shows Delete; confirmation names the scan, what is lost and the storage freed. |
| Touch and hold | Context menu with Rename and Delete. Rename is an alert with a text field (up to 80 characters). VoiceOver gets Rename and Delete as row actions. |
| Pull down | Reloads the list. The list also reloads when coming back to it. |
| States | Empty: "No scans yet" with a pointer to Diagnostics › Add sample to library. Error: "Scans could not be read" with Try again. Partial: a note counting unreadable scans. Action error shown in place above the list. |

## Scan detail (screen 4) — `ScanDetailView`, `ScanDetailModel`, `ModelView`

| Part | Behaviour |
|---|---|
| Title | Scan name, inline, one line, cut short with "…". |
| "•••" menu | Rename, Delete (confirmation as above; the screen closes after deleting). |
| Model view | SceneKit; drag turns, pinch zooms, two-finger drag moves; Reset view button. States: loading ("Opening model…"), shown, failed (reason). VoiceOver: "3D model", value "size, faces". |
| Chips | Shape (shows or hides the model); Edges disabled, "Edges: coming in a later build". |
| Details | Method (with detail level when known), Size (mm, or m from 1 m), Faces, Raw capture ("None" or "Kept · 196 MB"), On this phone, Saved. Footer gives the Check accuracy reason. |
| Bottom bar | Check accuracy (disabled; hint "Comes with the accuracy report"), Export (prominent; opens the existing Export sheet with this scan's model). |
| Sideways | Model on the left, details on the right. |

## Diagnostics — Sample model section

"Add sample to library" saves the stepped block as a scan (method Sample) and confirms
in place with its name, or shows the reason it failed. "Export sample model…" is kept.
