# Personas — LidarApp

Source: `requirements.md` (intent analysis), the Ideation intent statement, and the story
plan (`user-stories-questions.md`, Q1-B). There is one user, the owner. They use the app
in three modes, and each story names the mode it serves.

## The Owner

- **Role:** hobbyist maker; designs parts around existing objects in Autodesk Fusion and
  prints them. Sole user, sole tester, sole decision-maker.
- **Context:** iPhone 17 Pro Max on iOS 27; Windows computer; 3D printer (340 × 320 ×
  340 mm), digital calipers, CAD skills. No Mac and no iPhone development experience;
  relies on AI-written code and on what the app shows on the phone.
- **Works to:** `team-practices.md` — every merge is delivered to the phone, and
  sensor behaviour is checked there against a written checklist.

## Mode: Maker

- **Goal:** turn a real part into a 3D model with dimensions they can design against.
- **Pain points (from the third-party app):** coarse results; tracking loss and re-scans;
  export behind formats, paywalls and sign-ups; dimensions that could not be trusted.
- **Needs from the app:** two capture methods, guidance that reaches them while they look
  at the object, a file that opens in Fusion at true size, and no service in the way.

## Mode: Checker

- **Goal:** know, with numbers, how far a scan can be trusted for each kind and size of
  feature.
- **Pain points:** no basis for trust; accuracy claims with nothing behind them.
- **Needs from the app:** a reference object to print and measure, an automatic
  comparison that also says how reliable the comparison is, and a way to compare capture
  methods.

## Mode: Explorer

- **Goal:** understand first-hand what the LiDAR sensor and the cameras produce and where
  their limits are.
- **Pain points:** finished apps hide the sensor; no way to see raw behaviour.
- **Needs from the app:** live layers over the camera picture, a list of what the phone
  itself reports, and somewhere to write findings down.

## Relationships and Priority

The three modes are one person, so there is no conflict of interest to resolve, only an
order. Following the risk-first sequencing chosen in Ideation:

1. **Checker** leads, because whether scans can be trusted decides what the Maker can do.
2. **Maker** is the reason the app exists.
3. **Explorer** runs throughout; its findings inform both.

A fourth concern, the owner as the person who has to **keep the app working without a
Mac**, is served by the foundation stories (delivery and diagnostics) rather than by a
mode of its own.
