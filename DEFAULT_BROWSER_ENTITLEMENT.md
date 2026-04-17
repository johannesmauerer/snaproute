# Default Browser Entitlement Plan

## Current Status
SnapRoute uses Share Extension and Action Extension as a workaround. The default browser entitlement (`com.apple.developer.web-browser`) has not been requested yet.

## Requirements (from Apple docs)

To qualify, the app must:

1. Specify HTTP and HTTPS schemes in Info.plist (**done**)
2. NOT use UIWebView — must use WKWebView (**done** — we use WKWebView)
3. On launch, provide a URL text field, search tools, or curated bookmarks (**TODO** — need to add a URL bar)
4. Navigate directly to the specified URL and render web content (**done**)
5. Not redirect to unexpected locations (**done**)

## What we need to add before requesting

- [ ] Add a URL text field on the main/empty screen where users can type or paste a URL
- [ ] Consider adding basic history or bookmarks
- [ ] Test that the app properly renders any arbitrary HTTP/HTTPS URL

## Restrictions if granted

- Cannot claim Universal Links for specific domains
- Cannot use NSPhotoLibraryUsageDescription (only NSPhotoLibraryAddUsageDescription)
- Cannot use always-on location (only when-in-use)
- Cannot use NSHomeKitUsageDescription
- Cannot use NSBluetoothAlwaysUsageDescription
- Cannot use NSHealthShareUsageDescription or NSHealthUpdateUsageDescription

## How to request

1. Fill out the form: [Default browser entitlement request](https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser) (link to form is in the Apple docs page)
2. Can also request `com.apple.developer.browser.app-installation` at the same time
3. Apple reviews and may request changes
4. Timeline: 1-7 months based on developer reports

## Draft request description

> SnapRoute is a link routing utility that registers as the default browser to give users instant control over where links go. When a user taps any HTTP/HTTPS link, SnapRoute opens with a web preview and presents actions: open in Safari, send to ShelfRead (newsletter-to-EPUB service), or save to Obsidian. The app uses WKWebView for rendering, provides a URL input field, and navigates directly to the requested URL. It does not redirect, inject content, or modify the browsing experience. The app is open source (github.com/johannesmauerer/snaproute) and uses no third-party dependencies.
