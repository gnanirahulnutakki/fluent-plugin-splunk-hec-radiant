# frozen_string_literal: true

# Copyright 2018 Splunk Inc.
# Modifications Copyright 2025 G. Rahul Nutakki
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/output"
require "fluent/plugin/formatter"
require "fluent/plugin/splunk_hec_radiant/version"
require "fluent/plugin/splunk_hec_radiant/match_formatter"
require "net/http/persistent"
require "openssl"
require "oj"
require "zlib"
require "socket"
require "benchmark"
require "prometheus/client"

module Fluent
  module Plugin
    # Modernized Splunk HEC output plugin
    class SplunkHecRadiantOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output("splunk_hec_radiant", self)

      helpers :formatter

      KEY_FIELDS = %w[index time host source sourcetype metric_name metric_value].freeze
      TAG_PLACEHOLDER = "${tag}"

      MISSING_FIELD = Hash.new do |_h, k|
        $log.warn "expected field #{k} but it's missing" if defined?($log)
        MISSING_FIELD
      end.freeze

      desc "Protocol to use to call HEC API."
      config_param :protocol, :enum, list: %i[http https], default: :https

      desc "The hostname/IP to HEC, or HEC load balancer."
      config_param :hec_host, :string, default: ""

      desc "The port number to HEC, or HEC load balancer."
      config_param :hec_port, :integer, default: 8088

      desc "HEC REST API endpoint to use"
      config_param :hec_endpoint, :string, default: "services/collector"

      desc "Full url to connect to splunk. Example: https://mydomain.com:8088/apps/splunk"
      config_param :full_url, :string, default: ""

      desc "The HEC token."
      config_param :hec_token, :string, secret: true

      desc "If a connection has not been used for this number of seconds it will automatically be reset."
      config_param :idle_timeout, :integer, default: 5

      desc "The amount of time allowed between reading two chunks from the socket."
      config_param :read_timeout, :integer, default: nil

      desc "The amount of time to wait for a connection to be opened."
      config_param :open_timeout, :integer, default: nil

      desc "The path to a file containing a PEM-format CA certificate for this client."
      config_param :client_cert, :string, default: nil

      desc "The private key for this client."
      config_param :client_key, :string, default: nil

      desc "The path to a file containing a PEM-format CA certificate."
      config_param :ca_file, :string, default: nil

      desc "The path to a directory containing CA certificates in PEM format."
      config_param :ca_path, :string, default: nil

      desc "List of SSL ciphers allowed."
      config_param :ssl_ciphers, :array, default: nil

      desc "When set to true, TLS version 1.2 and above is required."
      config_param :require_ssl_min_version, :bool, default: true

      desc "Indicates if insecure SSL connection is allowed."
      config_param :insecure_ssl, :bool, default: false

      desc "Type of data sending to Splunk, `event` or `metric`."
      config_param :data_type, :enum, list: %i[event metric], default: :event

      desc "The Splunk index to index events."
      config_param :index, :string, default: nil

      desc "Field name to contain Splunk index name."
      config_param :index_key, :string, default: nil

      desc "The host field for events."
      config_param :host, :string, default: nil

      desc "Field name to contain host."
      config_param :host_key, :string, default: nil

      desc "The source field for events."
      config_param :source, :string, default: nil

      desc "Field name to contain source."
      config_param :source_key, :string, default: nil

      desc "The sourcetype field for events."
      config_param :sourcetype, :string, default: nil

      desc "Field name to contain sourcetype."
      config_param :sourcetype_key, :string, default: nil

      desc "Field name to contain Splunk event time."
      config_param :time_key, :string, default: nil

      desc "When data_type is metric, use metrics_from_event mode."
      config_param :metrics_from_event, :bool, default: true

      desc "Field name to contain metric name."
      config_param :metric_name_key, :string, default: nil

      desc "Field name to contain metric value."
      config_param :metric_value_key, :string, default: nil

      desc "When set to true, defined key fields will not be removed from the original event."
      config_param :keep_keys, :bool, default: false

      desc "Indicates if GZIP Compression is enabled."
      config_param :gzip_compression, :bool, default: false

      desc "App name"
      config_param :app_name, :string, default: "fluent_plugin_splunk_hec_radiant"

      desc "App version"
      config_param :app_version, :string, default: SplunkHecRadiant::VERSION

      desc "Define index-time fields for event data type, or metric dimensions for metric data type."
      config_section :fields, init: false, multi: false, required: false do
        # this is blank on purpose
      end

      desc "Indicates if 4xx errors should consume chunk"
      config_param :consume_chunk_on_4xx_errors, :bool, default: true

      config_section :format do
        config_set_default :usage, "**"
        config_set_default :@type, "json"
        config_set_default :add_newline, false
      end

      desc "Whether to allow non-UTF-8 characters in user logs."
      config_param :coerce_to_utf8, :bool, default: true

      desc "If coerce_to_utf8 is true, non-UTF-8 chars are replaced with this string."
      config_param :non_utf8_replacement_string, :string, default: " "

      desc "Any custom headers to include alongside requests made to Splunk"
      config_param :custom_headers, :hash, default: {}

      def initialize
        super
        @default_host = Socket.gethostname
        @extra_fields = nil
        @registry = ::Prometheus::Client.registry
      end

      def configure(conf)
        super
        raise Fluent::ConfigError, "One of `hec_host` or `full_url` is required." if @hec_host.empty? && @full_url.empty?

        check_conflict
        check_metric_configs
        @api = construct_api
        prepare_key_fields
        configure_fields(conf)
        configure_metrics(conf)
        pick_custom_format_method

        # @formatter_configs is from formatter helper
        @formatters = @formatter_configs.map do |section|
          SplunkHecRadiant::MatchFormatter.new(section.usage, formatter_create(usage: section.usage))
        end
      end

      def start
        super
        @conn = Net::HTTP::Persistent.new.tap do |c|
          c.verify_mode = @insecure_ssl ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
          c.cert = OpenSSL::X509::Certificate.new File.read(@client_cert) if @client_cert
          c.key = OpenSSL::PKey::RSA.new File.read(@client_key) if @client_key
          c.ca_file = @ca_file
          c.ca_path = @ca_path
          c.ciphers = @ssl_ciphers
          c.proxy = :ENV
          c.idle_timeout = @idle_timeout
          c.read_timeout = @read_timeout
          c.open_timeout = @open_timeout
          c.min_version = OpenSSL::SSL::TLS1_2_VERSION if @require_ssl_min_version

          c.override_headers["Content-Type"] = "application/json"
          c.override_headers["User-Agent"] = "fluent-plugin-splunk-hec-radiant/#{SplunkHecRadiant::VERSION}"
          c.override_headers["Authorization"] = "Splunk #{@hec_token}"
          c.override_headers["__splunk_app_name"] = @app_name.to_s
          c.override_headers["__splunk_app_version"] = @app_version.to_s
          @custom_headers.each do |header, value|
            c.override_headers[header] = value
          end
        end
      end

      def shutdown
        @conn&.shutdown
        super
      end

      def format(tag, time, record)
        # this method will be replaced in `configure`
      end

      def write(chunk)
        log.trace { "#{self.class}: Received new chunk, size=#{chunk.read.bytesize}" }

        t = Benchmark.realtime do
          write_to_splunk(chunk)
        end

        @metrics[:record_counter].increment(labels: metric_labels, by: chunk.size)
        @metrics[:bytes_counter].increment(labels: metric_labels, by: chunk.bytesize)
        @metrics[:write_records_histogram].observe(chunk.size, labels: metric_labels)
        @metrics[:write_bytes_histogram].observe(chunk.bytesize, labels: metric_labels)
        @metrics[:write_latency_histogram].observe(t, labels: metric_labels)
      end

      def multi_workers_ready?
        true
      end

      private

      def check_conflict
        KEY_FIELDS.each do |f|
          kf = "#{f}_key"
          next unless instance_variable_get("@#{f}") && instance_variable_get("@#{kf}")

          raise Fluent::ConfigError, "Can not set #{f} and #{kf} at the same time."
        end
      end

      def check_metric_configs
        return unless @data_type == :metric

        @metrics_from_event = false if @metric_name_key

        return if @metrics_from_event

        raise Fluent::ConfigError, "`metric_name_key` is required when `metrics_from_event` is `false`." unless @metric_name_key
        raise Fluent::ConfigError, "`metric_value_key` is required when `metric_name_key` is set." unless @metric_value_key
      end

      def prepare_key_fields
        KEY_FIELDS.each do |f|
          v = instance_variable_get "@#{f}_key"
          if v
            attrs = v.split(".").freeze
            if @keep_keys
              instance_variable_set "@#{f}", ->(_, record) { attrs.inject(record) { |o, k| o[k] } }
            else
              instance_variable_set "@#{f}", lambda { |_, record|
                attrs[0...-1].inject(record) { |o, k| o[k] }.delete(attrs[-1])
              }
            end
          else
            v = instance_variable_get "@#{f}"
            next unless v

            if v.include? TAG_PLACEHOLDER
              instance_variable_set "@#{f}", ->(tag, _) { v.gsub(TAG_PLACEHOLDER, tag) }
            else
              instance_variable_set "@#{f}", ->(_, _) { v }
            end
          end
        end
      end

      def configure_fields(conf)
        # This loop looks dumb, but it is used to suppress the unused parameter configuration warning
        conf.elements.select { |element| element.name == "fields" }.each do |element|
          element.each_pair { |k, _v| element.has_key?(k) }
        end

        return unless @fields

        @extra_fields = @fields.corresponding_config_element.map do |k, v|
          [k, v.empty? ? k : v]
        end.to_h
      end

      def pick_custom_format_method
        if @data_type == :event
          define_singleton_method :format, method(:format_event)
        else
          define_singleton_method :format, method(:format_metric)
        end
      end

      def format_event(tag, time, record)
        payload = {
          host: @host ? @host.call(tag, record) : @default_host,
          time: time.to_f.to_s
        }.tap do |p|
          if @time
            time_value = @time.call(tag, record)
            p[:time] = time_value unless time_value.nil?
          end

          p[:index] = @index.call(tag, record) if @index
          p[:source] = @source.call(tag, record) if @source
          p[:sourcetype] = @sourcetype.call(tag, record) if @sourcetype

          # delete nil fields otherwise will get format error from HEC
          %i[host index source sourcetype].each { |field| p.delete field if p[field].nil? }

          if @extra_fields
            p[:fields] = @extra_fields.map { |name, field| [name, record[field]] }.to_h
            p[:fields].delete_if { |_k, v| v.nil? }
            # if a field is already in indexed fields, then remove it from the original event
            @extra_fields.values.each { |field| record.delete field }
          end

          formatter = @formatters.find { |f| f.match? tag }
          record = formatter.format(tag, time, record) if formatter
          
          p[:event] = convert_to_utf8(record)
        end

        if payload[:event] == "{}"
          log.warn { "Event after formatting was blank, not sending" }
          return ""
        end

        Oj.dump(payload, mode: :compat)
      end

      def format_metric(tag, time, record)
        payload = {
          host: @host ? @host.call(tag, record) : @default_host,
          time: time.to_f.to_s,
          event: "metric"
        }.tap do |p|
          if @time
            time_value = @time.call(tag, record)
            p[:time] = time_value unless time_value.nil?
          end
        end

        payload[:index] = @index.call(tag, record) if @index
        payload[:source] = @source.call(tag, record) if @source
        payload[:sourcetype] = @sourcetype.call(tag, record) if @sourcetype

        unless @metrics_from_event
          fields = {
            metric_name: @metric_name.call(tag, record),
            _value: @metric_value.call(tag, record)
          }

          if @extra_fields
            fields.update @extra_fields.map { |name, field| [name, record[field]] }.to_h
            fields.delete_if { |_k, v| v.nil? }
          else
            fields.update record
          end

          fields.delete_if { |_k, v| v.nil? }
          payload[:fields] = convert_to_utf8(fields)

          return Oj.dump(payload, mode: :compat)
        end

        # when metrics_from_event is true, generate one metric event for each key-value in record
        payloads = record.map do |key, value|
          { fields: { metric_name: key, _value: value } }.merge!(payload)
        end

        payloads.map { |p| Oj.dump(p, mode: :compat) }.join
      end

      def construct_api
        if @full_url.empty?
          URI("#{@protocol}://#{@hec_host}:#{@hec_port}/#{@hec_endpoint.delete_prefix('/')}")
        else
          URI("#{@full_url.delete_suffix('/')}/#{@hec_endpoint.delete_prefix('/')}")
        end
      rescue StandardError
        if @full_url.empty?
          raise Fluent::ConfigError, "hec_host (#{@hec_host}) and/or hec_port (#{@hec_port}) are invalid."
        else
          raise Fluent::ConfigError, "full_url (#{@full_url}) is invalid."
        end
      end

      def write_to_splunk(chunk)
        post = Net::HTTP::Post.new @api.request_uri
        if @gzip_compression
          post.add_field("Content-Encoding", "gzip")
          gzip_stream = Zlib::GzipWriter.new StringIO.new
          gzip_stream << chunk.read
          post.body = gzip_stream.close.string
        else
          post.body = chunk.read
        end

        log.debug { "[Sending] Chunk: #{dump_unique_id_hex(chunk.unique_id)}(#{post.body.bytesize}B)." }
        log.trace { "POST #{@api} body=#{post.body}" }

        begin
          t1 = Time.now
          response = @conn.request @api, post
          t2 = Time.now
        rescue Net::HTTP::Persistent::Error => e
          raise e.cause
        end

        process_response(response, post.body, t2 - t1)
      end

      def process_response(response, request_body, duration)
        log.debug { "[Response] Status: #{response.code} Duration: #{duration}" }
        log.trace { "[Response] POST #{@api}: #{response.inspect}" }

        @metrics[:status_counter].increment(labels: metric_labels(status: response.code.to_s))

        raise_err = response.code.to_s.start_with?("5") || (!@consume_chunk_on_4xx_errors && response.code.to_s.start_with?("4"))

        # raise Exception to utilize Fluentd output plugin retry mechanism
        raise "Server error (#{response.code}) for POST #{@api}, response: #{response.body}" if raise_err

        # For both success response (2xx) we will consume the chunk.
        unless response.code.to_s.start_with?("2")
          log.error "#{self.class}: Failed POST to #{@api}, response: #{response.body}"
          log.debug { "#{self.class}: Failed request body: #{request_body}" }
        end
      end

      def convert_to_utf8(input)
        if input.is_a?(Hash)
          record = {}
          input.each do |key, value|
            record[convert_to_utf8(key)] = convert_to_utf8(value)
          end
          return record
        end
        return input.map { |value| convert_to_utf8(value) } if input.is_a?(Array)
        return input unless input.respond_to?(:encode)

        if @coerce_to_utf8
          input.encode(
            "utf-8",
            invalid: :replace,
            undef: :replace,
            replace: @non_utf8_replacement_string
          )
        else
          begin
            input.encode("utf-8")
          rescue EncodingError
            log.error do
              "Encountered encoding issues potentially due to non " \
                "UTF-8 characters. To allow non-UTF-8 characters and " \
                "replace them with spaces, please set \"coerce_to_utf8\" " \
                "to true."
            end
            raise
          end
        end
      end

      def configure_metrics(conf)
        @metric_labels = {
          type: conf["@type"],
          plugin_id: plugin_id
        }

        @metrics = {
          record_counter: register_metric(::Prometheus::Client::Counter.new(
                                            :splunk_output_write_records_count,
                                            docstring: "The number of log records being sent",
                                            labels: metric_label_keys
                                          )),
          bytes_counter: register_metric(::Prometheus::Client::Counter.new(
                                           :splunk_output_write_bytes_count,
                                           docstring: "The number of log bytes being sent",
                                           labels: metric_label_keys
                                         )),
          status_counter: register_metric(::Prometheus::Client::Counter.new(
                                            :splunk_output_write_status_count,
                                            docstring: "The count of sends by response_code",
                                            labels: metric_label_keys(status: "")
                                          )),
          write_bytes_histogram: register_metric(::Prometheus::Client::Histogram.new(
                                                   :splunk_output_write_payload_bytes,
                                                   docstring: "The size of the write payload in bytes",
                                                   buckets: [1024, 23_937, 47_875, 95_750, 191_500, 383_000, 766_000, 1_149_000],
                                                   labels: metric_label_keys
                                                 )),
          write_records_histogram: register_metric(::Prometheus::Client::Histogram.new(
                                                     :splunk_output_write_payload_records,
                                                     docstring: "The number of records written per write",
                                                     buckets: [1, 10, 25, 100, 200, 300, 500, 750, 1000, 1500],
                                                     labels: metric_label_keys
                                                   )),
          write_latency_histogram: register_metric(::Prometheus::Client::Histogram.new(
                                                     :splunk_output_write_latency_seconds,
                                                     docstring: "The latency of writes",
                                                     labels: metric_label_keys
                                                   ))
        }
      end

      def metric_labels(other_labels = {})
        @metric_labels.merge other_labels
      end

      def metric_label_keys(other_labels = {})
        (@metric_labels.merge other_labels).keys
      end

      def register_metric(metric)
        if !@registry.exist?(metric.name)
          @registry.register(metric)
        else
          @registry.get(metric.name)
        end
      end
    end
  end
end
