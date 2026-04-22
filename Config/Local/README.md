# Local xcconfig overlays

These files are intentionally untracked. Copy one of the example files below to
the matching filename and fill in local-only values:

- `Config/Local/Debug.example.xcconfig` -> `Config/Local/Debug.xcconfig`
- `Config/Local/Release.example.xcconfig` -> `Config/Local/Release.xcconfig`
- `Config/Local/Staging.example.xcconfig` -> `Config/Local/Staging.xcconfig`

The app target reads runtime values from `Info.plist`, but `Info.plist` now
pulls those values from build settings defined in the selected xcconfig file.
That keeps tracked plist contents stable while letting local builds inject real
credentials.
