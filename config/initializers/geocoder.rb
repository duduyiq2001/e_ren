Geocoder.configure(
  # Geocoding options
  timeout: 5,                              # geocoding service timeout (secs)
  lookup: :google,                         # Google Maps Geocoding API
  language: :en,                           # ISO-639 language code
  use_https: true,                         # use HTTPS for lookup requests
  api_key: ENV['GOOGLE_MAPS_API_KEY'],    # API key for Google Maps (set in .env)

  # Cache configuration - uses Rails cache (Solid Cache in production)
  cache: Rails.cache,
  cache_options: {
    expiration: 7.days,
    prefix: 'geocoder:'
  },

  # Calculation options
  units: :mi,                              # :km for kilometers or :mi for miles
  distances: :spherical                    # :spherical for accurate geographic distances
)
