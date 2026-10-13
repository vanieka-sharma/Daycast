# Daycast

Daycast is a native SwiftUI iOS app that searches for a city and ranks four activities for the next 7 days using Open-Meteo forecast data:

- Skiing
- Surfing
- Outdoor sightseeing
- Indoor sightseeing

## Setup

- Xcode 17+
- iOS Simulator runtime installed (used in examples below)

Open `Daycast.xcodeproj` in Xcode and run the `Daycast` scheme.

## Build and Test

```bash
cd /Users/ZX1IZJZ/Desktop/MySpace/Daycast
xcodebuild -project Daycast.xcodeproj -scheme Daycast -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Daycast.xcodeproj -scheme Daycast -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DaycastTests test
```

## Architecture

The app uses a lean MVVM + service/repository-style split:

- `Daycast/Features/Search/`
  - `SearchView`: SwiftUI rendering and user actions
  - `SearchViewModel`: explicit UI state and orchestration
- `Daycast/Domain/`
  - Models: `City`, `DailyForecast`, `Activity`, `ActivityRecommendation`
  - `ActivityRankingService`: deterministic activity scoring logic
- `Daycast/Data/`
  - Open-Meteo API clients (`OpenMeteoGeocodingClient`, `OpenMeteoForecastClient`)
  - `RecommendationService` to compose city search + forecast + ranking
  - `HTTPClient` protocol for mockable networking
- `Daycast/Shared/`
  - `AppError` for typed user-facing errors

Dependency injection is done in `DaycastApp.swift`.

## API Usage

### Geocoding API

- Endpoint: `https://geocoding-api.open-meteo.com/v1/search`
- Purpose: city search by name

### Forecast API

- Endpoint: `https://api.open-meteo.com/v1/forecast`
- Requested daily fields:
  - `temperature_2m_max`
  - `temperature_2m_min`
  - `precipitation_sum`
  - `wind_speed_10m_max`
  - `weather_code`
  - `snowfall_sum`
- `forecast_days=7`

The client also supports legacy key variants (`windspeed_10m_max`, `weathercode`) defensively.

## Ranking Methodology

`ActivityRankingService` computes a weekly recommendation per activity:

1. Score each day deterministically from available forecast inputs
2. Average daily scores into a weekly score
3. Compute confidence (data quality + coverage based)
4. Add explanation and limitations

### Transparency and missing-data behavior

- Missing required inputs for a day => that day is not scored for that activity
- If all days are unscored => activity score is `nil` with explicit message
- Missing optional inputs reduce confidence and add limitations
- No unavailable weather information is invented

## Activity-specific assumptions and limitations

### Skiing

Uses temperature, precipitation, and snowfall when available.

Limitations:
- No resort data
- No elevation/snow depth/lift status
- If snowfall is unavailable, a lower-confidence temp+precipitation proxy is used

### Surfing

Uses weather-based comfort proxies (wind/temperature/precipitation).

Limitations:
- No marine swell/tide/current data
- Surfing confidence is intentionally capped to avoid overclaiming

## UI States

`SearchViewModel.State` explicitly models:

- `idle`
- `searchingCities`
- `cityResults`
- `loadingRecommendations`
- `loaded`
- `empty`
- `error` (with retry support)

## Testing

### Included tests

- `ActivityRankingServiceTests`
  - ranking behavior
  - score/confidence bounds
  - missing-data behavior
  - skiing/surfing limitations behavior
- `OpenMeteoMappingTests`
  - geocoding mapping
  - forecast mapping and key compatibility
- `SearchViewModelTests`
  - state transitions for search, error, retry, and loading recommendations

## Trade-offs

- Kept architecture intentionally lean for take-home scope
- Avoided extra abstraction layers beyond what improved testability/readability
- Prioritized correctness, resilience, and clear communication over visual polish

## Production-readiness notes

Potential next improvements:

- Add debounced search as user types
- Add caching and offline fallback
- Add per-day recommendation breakdown UI
- Add instrumentation and analytics
- Add localization and accessibility refinements

## AI-assisted development note

An AI coding assistant was used to help with scaffolding, implementation, and tests. All logic, assumptions, and limitations were reviewed and aligned to the assignment requirements.
