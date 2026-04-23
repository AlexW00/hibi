# Privacy Policy

**Hibi — Calendar App**
**Last updated:** April 23, 2026

## Overview

Hibi is a personal calendar app for iOS. It is designed with privacy in mind: your data stays on your device, and we do not operate any servers or collect any personal information.

## Data We Access

### Calendar Data

Hibi reads your device's calendar events through Apple's EventKit framework to display them in the app. Calendar data is accessed read-only for display purposes. When you create or edit events, the app uses Apple's built-in event editor, which writes directly to your device's calendar database.

Your calendar data is never transmitted off your device by Hibi.

### Location Data

Hibi requests your location to fetch weather information for your current area and to display a city name on the day view. Location data is used only for these purposes and is not stored persistently or transmitted to any server other than Apple's WeatherKit service.

### Weather Data

Hibi uses Apple's WeatherKit service to retrieve weather forecasts based on your current location. This request is handled entirely through Apple's frameworks and is subject to [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

## Data We Store

Hibi stores a small amount of preference data locally on your device using UserDefaults:

- Your calendar visibility preferences (which calendars to show or hide)
- Your chosen appearance setting
- A record of which version's changelog has been shown

No personal data, calendar content, or location history is stored by Hibi.

## Data We Do Not Collect

- We do not collect, transmit, or store any personal information
- We do not use analytics or tracking frameworks
- We do not use third-party SDKs or advertising networks
- We do not have user accounts or any form of registration
- We do not operate any servers or backend services

## Third-Party Services

The only external service Hibi communicates with is **Apple WeatherKit**, which is operated by Apple and governed by Apple's own privacy policy. No other third-party services are used.

## Children's Privacy

Hibi does not collect any personal information from anyone, including children under the age of 13.

## Changes to This Policy

If we update this privacy policy, the revised version will be posted in this repository with an updated date.

## Contact

If you have questions about this privacy policy, please open an issue in this repository or contact:

**Alexander Weichart**
Email: alexweichart@gmail.com
