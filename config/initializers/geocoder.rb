Geocoder.configure(
  # Geocoding options
  timeout: 5,                              # geocoding service timeout (secs)
  lookup: Rails.env.test? ? :test : :google, # Use test stub in test env
  language: :en,                           # ISO-639 language code
  use_https: true,                         # use HTTPS for lookup requests
  api_key: ENV['GOOGLE_MAP'],              # API key for Google Maps (set in .env)

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

# Stub geocoder responses in test environment
if Rails.env.test?
  Geocoder::Lookup::Test.set_default_stub(
    [
      {
        'coordinates'  => [37.7749, -122.4194],
        'address'      => 'San Francisco, CA, USA',
        'city'         => 'San Francisco',
        'state'        => 'California',
        'country'      => 'United States',
        'country_code' => 'US'
      }
    ]
  )
end
