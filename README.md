# 1pm Challenge 3

A minimal iOS app built with SwiftUI in Xcode.

## Requirements

- Xcode 16 or later (developed with Xcode 27)
- iOS 17.0+ deployment target

## Getting started

1. Clone the repo:
   ```sh
   git clone https://github.com/raahatshaikh98/1pm-Challenge-3.git
   ```
2. Open `1pm Challenge 3.xcodeproj` in Xcode.
3. Select an iPhone simulator and press **⌘R** to run.

## Project structure

```
1pm Challenge 3/
├── 1pm Challenge 3.xcodeproj      # Xcode project (shared scheme included)
├── 1pm Challenge 3/
│   ├── ContentView.swift          # The whole app: ContentView + @main App
│   └── Assets.xcassets            # App icon & accent color
├── .gitignore
└── README.md
```

## Notes

- The bundle identifier is `com.raahatshaikh98.Challenge3`. Change it under
  **Target → Signing & Capabilities** if you want your own.
- New files dropped into the `1pm Challenge 3/` folder are added to the target
  automatically (Xcode's synchronized folders).
- No signing team is set yet. Pick your team in **Signing & Capabilities** to
  run on a physical device.
