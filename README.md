# LeGame Project Workshop

**Project ID:** LEGAME-PID000001

A simple workshop-style application for creating **Website** or **Application** projects.

## Storage Path
Projects are stored at:
```
/storage/emulated/0/Android/data/com.legame.project/projects/"projectname"-"type"/
```
- `projectname-website/` for Website projects
- `projectname-app/` for Application projects

## Features Implemented
- Create Project (name + type: Website / Application)
- List all projects on home screen
- Delete projects
- Open project → Editor + Project file browser
- Bottom navigation: **EDITOR** | **PROJECT**
- Top bar: **Leave** | **Save** | **Run**
- PROJECT tab:
  - Browse files & folders
  - Create new file / folder
  - Delete file / folder
  - Click file → opens in EDITOR
  - Import files (images, videos, code files)
- EDITOR tab:
  - List of open files (tabs)
  - Simple code editor
  - Save current file

## How to Run

1. Make sure you have Flutter installed.
2. Clone this repository.
3. Open terminal in the project folder and run:

```bash
flutter create . --project-name le_game_project
flutter pub get
flutter run
```

### Important Android Permissions
After `flutter create`, open:

`android/app/src/main/AndroidManifest.xml`

Add these permissions **before** the `<application>` tag:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
```

Also set the package name if needed (in `android/app/build.gradle` and `AndroidManifest.xml`) to:
```
com.legame.project
```

## Next Steps (can be added later)
- Better code editor with syntax highlighting
- Real Run / Preview for Website (WebView)
- Application run simulation
- Rename files/folders
- Multiple open tabs improvements
