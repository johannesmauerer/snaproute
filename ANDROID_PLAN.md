# SnapRoute Android — Implementation Plan

## Overview

Native Kotlin + Jetpack Compose Android app. Mirrors the iOS app 1:1. Registers as a browser so Android routes all link taps to it, then presents three routing actions over a WebView preview.

## Tech Stack

- Kotlin, Jetpack Compose UI, single-activity architecture
- No external dependencies beyond AndroidX
- Min SDK 26 (Android 8.0), Target SDK 35
- Package: `com.rawplusdry.snaproute`
- Project location: `~/Engineering/snaproute-android`

## Project Structure

```
snaproute-android/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradle/wrapper/
├── gradlew
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/rawplusdry/snaproute/
│       │   ├── MainActivity.kt
│       │   ├── URLRouter.kt
│       │   ├── Settings.kt
│       │   ├── BrowserHelper.kt
│       │   ├── WebViewComposable.kt
│       │   └── ui/
│       │       ├── theme/Theme.kt
│       │       ├── ContentScreen.kt
│       │       ├── ActionScreen.kt
│       │       ├── SettingsScreen.kt
│       │       └── Components.kt
│       └── res/
│           ├── values/{strings,colors,themes}.xml
│           ├── mipmap-*/ic_launcher.png
│           └── xml/network_security_config.xml
├── AGENT.md
└── README.md
```

## Key Android-Specific Details

### Browser Registration (AndroidManifest.xml)

```xml
<activity android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="http" />
    </intent-filter>
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" />
    </intent-filter>
</activity>

<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
```

- `singleTask` — new links reuse existing activity via `onNewIntent`
- `<queries>` — required for Android 11+ to find other browsers

### BrowserHelper — Finding the Real Browser

```kotlin
object BrowserHelper {
    fun openInExternalBrowser(context: Context, uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW, uri)
        val resolveInfos = context.packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )
        val otherBrowser = resolveInfos.firstOrNull {
            it.activityInfo.packageName != context.packageName
        }
        if (otherBrowser != null) {
            intent.setPackage(otherBrowser.activityInfo.packageName)
            context.startActivity(intent)
        } else {
            context.startActivity(Intent.createChooser(intent, "Open with"))
        }
    }
}
```

### ShelfRead POST (HttpURLConnection, no OkHttp)

Use `java.net.HttpURLConnection` on `Dispatchers.IO`. `org.json.JSONObject` is part of Android SDK.

### Obsidian Save

Same `obsidian://new` URI scheme as iOS, launched via `Intent(ACTION_VIEW, uri)`.

### Gotchas

1. **onNewIntent**: Must extract URL from new intent and push to URLRouter
2. **Cleartext HTTP**: Enable via `network_security_config.xml`
3. **WebView JavaScript**: Must explicitly enable
4. **Edge-to-edge**: Handle system bar insets
5. **Back press**: SnapRoute stays in back stack after opening browser — correct behavior

### Build Steps

```bash
cd ~/Engineering/snaproute-android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
# Set as default: Settings > Apps > Default apps > Browser > SnapRoute
```

### Dependencies (all AndroidX, no third-party)

```kotlin
implementation(platform("androidx.compose:compose-bom:2024.12.01"))
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.material3:material3")
implementation("androidx.activity:activity-compose:1.9.3")
implementation("androidx.core:core-ktx:1.15.0")
```
