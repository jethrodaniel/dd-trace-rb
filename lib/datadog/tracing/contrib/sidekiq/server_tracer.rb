# typed: true

require 'datadog/tracing'
require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/contrib/analytics'
require 'datadog/tracing/contrib/sidekiq/ext'
require 'datadog/tracing/contrib/sidekiq/tracing'
require 'datadog/tracing/contrib/utils/quantization/hash'

module Datadog
  module Tracing
    module Contrib
      module Sidekiq
        # Tracer is a Sidekiq server-side middleware which traces executed jobs
        class ServerTracer
          include Tracing

          def initialize(options = {})
            @sidekiq_service = options[:service_name] || configuration[:service_name]
            @error_handler = options[:error_handler] || configuration[:error_handler]
          end

          def call(worker, job, queue)
            resource = job_resource(job)

            Datadog::Tracing.trace(
              Ext::SPAN_JOB,
              service: @sidekiq_service,
              span_type: Datadog::Tracing::Metadata::Ext::AppTypes::TYPE_WORKER,
              on_error: @error_handler
            ) do |span|
              span.resource = resource

              span.set_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
              span.set_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION, Ext::TAG_OPERATION_JOB)

              # Set analytics sample rate
              if Contrib::Analytics.enabled?(configuration[:analytics_enabled])
                Contrib::Analytics.set_sample_rate(span, configuration[:analytics_sample_rate])
              end

              # Measure service stats
              Contrib::Analytics.set_measured(span)

              span.set_tag(Ext::TAG_JOB_ID, job['jid'])
              span.set_tag(Ext::TAG_JOB_RETRY, job['retry'])
              span.set_tag(Ext::TAG_JOB_RETRY_COUNT, job['retry_count'])
              span.set_tag(Ext::TAG_JOB_QUEUE, job['queue'])
              span.set_tag(Ext::TAG_JOB_WRAPPER, job['class']) if job['wrapped']
              span.set_tag(Ext::TAG_JOB_DELAY, 1000.0 * (Time.now.utc.to_f - job['enqueued_at'].to_f))
              span.set_tag(Ext::TAG_JOB_ARGS, quantize_args(job['args'])) if !job['args'].nil? && !job['args'].empty?

              yield
            end
          end

          private

          def quantize_args(args)
            quantize_options = configuration[:quantize][:args] || {}
            Contrib::Utils::Quantization::Hash.format(args, quantize_options)
          end

          def configuration
            Datadog.configuration.tracing[:sidekiq]
          end
        end
      end
    end
  end
end
