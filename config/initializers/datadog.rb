# Datadog APM configuration
# Only enable in production to avoid noise in development/test
if Rails.env.production? && ENV['DD_AGENT_HOST'].present?
  require 'datadog'

  Datadog.configure do |c|
    c.service = 'e-ren'
    c.env = ENV.fetch('DD_ENV', 'prod')
    c.version = ENV.fetch('DD_VERSION', '1.0.0')

    # Enable Rails auto-instrumentation
    c.tracing.instrument :rails
    c.tracing.instrument :active_record
    c.tracing.instrument :action_pack
    c.tracing.instrument :action_view
    c.tracing.instrument :active_job
    c.tracing.instrument :action_mailer

    # HTTP client tracing (add back if using httprb or faraday gems)
    # c.tracing.instrument :httprb
    # c.tracing.instrument :faraday

    # Agent connection settings (set via env vars from Helm)
    c.agent.host = ENV.fetch('DD_AGENT_HOST', 'localhost')
    c.agent.port = ENV.fetch('DD_TRACE_AGENT_PORT', 8126).to_i

    # Runtime metrics (CPU, memory, GC stats)
    c.runtime_metrics.enabled = true

    # Sampling rate (1.0 = 100% of traces)
    c.tracing.sampling.default_rate = 1.0
  end
end
