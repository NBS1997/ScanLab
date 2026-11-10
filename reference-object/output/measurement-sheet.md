# ScanLab reference object - measurement sheet

Table version 1. Overall design size 159.276 x 105 x 108 mm (left to right x front to back x height).

## Why you are measuring

Every printer makes parts a little different from the design: plastic shrinks as it cools, holes come out
small and posts come out large. The app compares each scan with **your caliper value**, not the design
value. The caliper value is the truth; the design value is only there so you can spot a slip of the pen.
If a reading is more than about 0.5 mm away from the design value, measure it again.

## Before you measure

- Let the print cool for at least an hour after it comes off the bed.
- Zero the calipers with the jaws closed. Measure each feature three times and write down the average.
- Hold the object the same way as this sheet: the **long straight edge towards you**, the **tall tower at
  the back left**, the **stairs at the front right**, and the **curved side on your left**.
- Leave a box blank rather than guess. A blank feature is simply left out of the accuracy report.

## Print guidance

- **Filament:** matt, light-coloured (white or light grey matt PLA is ideal). Shiny or dark plastic
  confuses the depth sensor.
- **Orientation:** flat on the bed, underside down, exactly as the STL is laid out. No supports are
  needed: nothing overhangs more than 45 degrees.
- **Settings:** 0.2 mm layers, 3 walls, 15-20% infill (gyroid or grid), no brim needed. Turn off any
  slicer setting that compensates holes or shrinks the first layer, so the print matches the design as
  closely as it naturally does.
- Do not sand or paint it; measure and scan it as printed.

## Features

### Lengths between faces

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| L1 | **Thickness of the thin upright rib near the right edge.** Close the outside jaws gently on the thin rib near the right-hand edge, across its thickness (left to right). | 1.6 mm | |
| L2 | **Width of the through slot behind the dome.** Put the small inside jaws into the long narrow slot and open them across its width (left to right). | 6 mm | |
| L3 | **Width of the tall tower, left face to right face.** Close the outside jaws on the tall tower from left to right, about halfway up, away from the rounded corner. | 22 mm | |
| L4 | **Depth of the tall tower, front face to back face.** Close the outside jaws on the tall tower from front to back, about halfway up. | 26 mm | |
| L5 | **Front-to-back depth of the plate at the left, front edge to the short straight back edge.** Close the outside jaws on the plate edges from front to back, between the large hole and the curved left side, where the back edge is straight and parallel to the front edge (about 4 cm in from the corner cut). | 105 mm | |
| L6 | **Overall height, underside to the top of the tall tower.** Close the outside jaws from the underside of the plate to the top of the tall tower, reaching in from the curved left side. | 108 mm | |

### Steps and heights

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| S1 | **Height of the low square pad above the plate.** Stand the end of the calipers on the low square pad and slide the depth rod down until it touches the plate beside the pad. | 1.5 mm | |
| S2 | **Plate thickness, underside to plate top.** Close the outside jaws on the plate at the front edge, underside to top, clear of the ramp and stairs. | 8 mm | |
| S3 | **Height of the lower stair tread above the plate.** Stand the end of the calipers on the lower stair tread and slide the depth rod down to the plate on its left. | 10 mm | |
| S4 | **Rise from the lower stair tread to the upper stair tread.** Stand the end of the calipers on the upper stair tread and slide the depth rod down to the lower tread. | 15 mm | |
| S5 | **Height of the tall tower above the plate.** Hard to reach directly: measure L6 (overall height) and S2 (plate thickness) and write L6 minus S2 here. If your depth rod is long enough, you can instead stand the calipers on the tower top and drop the rod to the plate. | 100 mm | |

### Holes

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| H1 | **Diameter of the 2 mm round through hole.** Put the small inside jaws into the round hole and open them until they touch both sides; rock them slightly and keep the largest reading. The jaw tips may be too thick for a hole this small; if so, find the largest drill bit that slides in and measure the drill bit instead. | 2 mm | |
| H2 | **Diameter of the 5 mm round through hole.** Put the small inside jaws into the round hole and open them until they touch both sides; rock them slightly and keep the largest reading. | 5 mm | |
| H3 | **Diameter of the 12 mm round through hole.** Put the small inside jaws into the round hole and open them until they touch both sides; rock them slightly and keep the largest reading. | 12 mm | |
| H4 | **Diameter of the 30 mm round through hole.** Put the small inside jaws into the round hole and open them until they touch both sides; rock them slightly and keep the largest reading. | 30 mm | |

### Round posts (bosses)

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| B1 | **Diameter of the 2 mm round post (4 mm tall).** Close the outside jaws across the round post, near its top, and keep the smallest steady reading. | 2 mm | |
| B2 | **Diameter of the 8 mm round post (6 mm tall).** Close the outside jaws across the round post, near its top, and keep the smallest steady reading. | 8 mm | |
| B3 | **Diameter of the 20 mm round post (12 mm tall).** Close the outside jaws across the round post, near its top, and keep the smallest steady reading. | 20 mm | |
| B4 | **Diameter of the 40 mm round post (4 mm tall).** Close the outside jaws across the round post, near its top, and keep the smallest steady reading. | 40 mm | |

### Angles between faces

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| A1 | **Small chamfer on the front top edge of the upper stair, against the stair top.** Too small for a protractor. With the depth rod, measure how far the chamfer runs down the front face (design 1.2 mm), and with the jaws how far it runs back across the top (design 1.2 mm). Angle = arctan(down / back). Leave blank if you cannot measure it. | 45 degrees | |
| A2 | **Corner cut at the front left, against the front face.** Hold a protractor against the long straight front face with its arm along the cut-off front-left corner. If your protractor reads more than 90 degrees, write 180 minus the reading. | 30 degrees | |
| A3 | **Sloping top of the ramp, against the plate top.** Stand a protractor on the plate beside the ramp with its arm along the slope. No protractor? Measure the ramp's tall end with the depth rod (design 13.99 mm) and its length along the plate with the jaws (design 30 mm); angle = arctan(height / length). | 25 degrees | |
| A4 | **Long slanted back edge, against the right-hand face at the back right corner.** Hold a protractor at the back right corner, one arm along the right-hand face and the other along the long slanted back face. If your protractor reads more than 90 degrees, write 180 minus the reading. | 80 degrees | |

### Curved surfaces

| ID | What to measure | Design value | Your caliper value |
|---|---|---|---|
| C1 | **Radius of the rounded front-right vertical edge of the tall tower.** Calipers cannot measure this directly. Use a radius gauge if you have one; otherwise leave blank. | 1.5 mm | |
| C2 | **Radius of the half-ball dome.** Stand the end of the calipers on the top of the dome and slide the depth rod down to the plate; for a half ball the height equals the radius. (Check: the dome's width across its base should be twice this.) | 15 mm | |
| C3 | **Radius of the gently curved left side.** Lay a steel rule on edge against the two ends of the curved left side (design gap 92.30 mm between the ends). With the depth rod, measure the gap between the rule and the middle of the curve (design 7.28 mm). Radius = (ends gap x ends gap) / (8 x middle gap) + middle gap / 2. | 150 mm | |

## Done?

Enter your caliper values in the app (Reference object screen) once that screen exists. Keep this sheet:
if you ever reprint the object, measure the new print and enter its values again.
