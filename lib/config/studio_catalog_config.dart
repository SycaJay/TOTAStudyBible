/// Public JSON URL for **Pastor Elliot Digital Studio** (Discover tab), optional.
/// If this is empty, the app loads the same shape from Firestore `studio/catalog`
/// (see `StudioCatalogRepository`). You can also pass `--dart-define=STUDIO_CATALOG_URL=...`.
///
/// When set, response body must be JSON:
/// ```json
/// {
///   "videos": [{ "title": "...", "url": "https://..." }],
///   "audio": [{ "title": "...", "url": "https://..." }]
/// }
/// ```
///
/// Podcasts and sermon MP3s go under `audio`; video pages or YouTube links under `videos`.
const String kPastorElliotStudioCatalogUrl = '';
