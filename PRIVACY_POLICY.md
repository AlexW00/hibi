# Privacy Policy

**Hibi — Calendar App**
**Last updated:** July 9, 2026

## Overview

Hibi is a personal calendar app for iOS. It is designed with privacy in mind: we do not operate any servers, do not collect any personal information, and cannot see your data. Your data lives on your device and, if you use iCloud, syncs privately between your own devices through your personal Apple iCloud account — it is never sent to us.

## Data We Access

### Calendar Data

Hibi reads your device's calendar events through Apple's EventKit framework to display them in the app. Calendar data is accessed read-only for display purposes. When you create or edit events, the app uses Apple's built-in event editor, which writes directly to your device's calendar database.

Your calendar data is never transmitted off your device by Hibi.

### Location Data

Hibi requests your location to fetch weather information for your current area and to display a city name on the day view. Location data is used only for these purposes and is not stored persistently or transmitted to any server other than Apple's WeatherKit service.

### Weather Data

Hibi uses Apple's WeatherKit service to retrieve weather forecasts based on your current location. This request is handled entirely through Apple's frameworks and is subject to [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

## Data We Store

Hibi stores your preferences and any personalizations you create locally on your device. This includes:

- Your settings (such as calendar visibility, appearance, temperature and time-format choices, and font preference)
- Your page personalizations: the paper style and layout you choose, and any decorations you add to a day — including text and notes you write on a day, drawings you make, and stickers you place (including images you cut out from your camera or Photo Library to make a sticker)

We do not store your location history, and Hibi never uploads your device's calendar events.

### iCloud Sync

If you are signed in to iCloud and have iCloud enabled for Hibi, the settings and personalizations described above sync across your own Apple devices using Apple's iCloud. Two Apple technologies handle this:

- **iCloud key-value storage** for your settings.
- **iCloud with CloudKit** (a private database in your personal iCloud account) for your page personalizations — paper style, layout, and per-day decorations such as your notes, drawings, and stickers.

This data is stored in **your own private iCloud account**, which is controlled by you and governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). Hibi operates no servers, and we have no access to this data — we cannot read it. Your device's calendar events are **not** synced by Hibi; they remain in your device's calendar and are only read for display.

You can turn this off at any time by disabling iCloud for Hibi in the iOS Settings app (Settings → your name → iCloud). Hibi then keeps all data on-device only.

## Data We Do Not Collect

- We do not collect, receive, or have any access to your personal information or content (including anything synced through iCloud, which stays inside your own Apple account)
- We do not use analytics or tracking frameworks
- We do not use third-party SDKs or advertising networks
- We do not have user accounts or any form of registration with us
- We do not operate any servers or backend services

## Third-Party Services

The external services Hibi relies on are operated by **Apple** and governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/):

- **Apple WeatherKit** — to retrieve weather forecasts for your location.
- **Apple iCloud (iCloud key-value storage and CloudKit)** — to sync your settings and personalizations across your own devices, stored in your personal iCloud account.

No other third-party services are used.

## Children's Privacy

Hibi does not collect any personal information from anyone, including children under the age of 13.

## Changes to This Policy

If we update this privacy policy, the revised version will be posted in this repository with an updated date.

## Contact

If you have questions about this privacy policy, please open an issue in this repository or contact:

**Alexander Weichart**
Email: alexweichart@gmail.com
