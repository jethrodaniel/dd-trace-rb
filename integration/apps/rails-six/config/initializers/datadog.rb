require 'datadog/statsd'
require 'ddtrace'
require 'datadog/appsec'

Datadog.configure do |c|
  c.env = 'integration'
  c.service = 'acme-rails-six'
  c.diagnostics.debug = true if Datadog::DemoEnv.feature?('debug')
  c.runtime_metrics.enabled = true if Datadog::DemoEnv.feature?('runtime_metrics')

  if Datadog::DemoEnv.feature?('tracing')
    c.tracing.analytics.enabled = true if Datadog::DemoEnv.feature?('analytics')

    # c.tracing.span.after_finish = proc do |span|
    #   if span.service != Datadog.configuration.service && !span.has_tag?('_dd.base_service')
    #     span.set_tag('_dd.base_service', Datadog.configuration.service)
    #     span.set_tag('tagging_base_service', 'true')
    #   end
    # end

    c.tracing.instrument :rails
    c.tracing.instrument :redis, service_name: 'acme-redis'
    c.tracing.instrument :resque
  end

  if Datadog::DemoEnv.feature?('appsec')
    c.appsec.enabled = true

    c.appsec.instrument :rails
  end

  if Datadog::DemoEnv.feature?('profiling')
    if Datadog::DemoEnv.feature?('pprof_to_file')
      # Reconfigure transport to write pprof to file
      c.profiling.exporter.transport = Datadog::DemoEnv.profiler_file_transport
    end
  end
end

# Datadog::Tracing.before_flush(
#   Datadog::Tracing::Pipeline::SpanProcessor.new do |span|
#     if span.service != Datadog.configuration.service && !span.has_tag?('_dd.base_service')
#       span.set_tag('_dd.base_service', Datadog.configuration.service)
#       span.set_tag('tagging_base_service', 'true')
#     end
#   end
# )
