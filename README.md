# fluent-plugin-splunk-hec-radiant

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Ruby](https://img.shields.io/badge/ruby-3.0+-red.svg)](https://www.ruby-lang.org)

A **modernized and actively maintained** Fluentd output plugin for sending events and metrics to [Splunk](https://www.splunk.com) via the [HTTP Event Collector (HEC) API](http://dev.splunk.com/view/event-collector/SP-CAAAE7F).

This is a fork of the original [fluent-plugin-splunk-hec](https://github.com/splunk/fluentd-hec) by Splunk Inc., which has reached end-of-support. This version includes:

- ✅ **Ruby 3.x support** (requires Ruby 3.0+)
- ✅ **Modern dependencies** (Fluentd 1.16+, latest gems)
- ✅ **Better performance** (using `oj` for JSON instead of `multi_json`)
- ✅ **Enhanced security** (TLS 1.2+ by default)
- ✅ **Active maintenance** and bug fixes
- ✅ **Comprehensive test coverage**

## Installation

### RubyGems

```bash
gem install fluent-plugin-splunk-hec-radiant
```

### Bundler

Add to your `Gemfile`:

```ruby
gem "fluent-plugin-splunk-hec-radiant"
```

Then run:

```bash
bundle install
```

### td-agent

```bash
td-agent-gem install fluent-plugin-splunk-hec-radiant
```

## Configuration

The plugin is registered as `@type splunk_hec_radiant`.

### Basic Configuration

```xml
<match **>
  @type splunk_hec_radiant
  hec_host 12.34.56.78
  hec_port 8088
  hec_token 00000000-0000-0000-0000-000000000000
</match>
```

This sends events to Splunk HEC at `https://12.34.56.78:8088` using the specified token.

### Full Configuration Example

```xml
<match **>
  @type splunk_hec_radiant
  
  # HEC endpoint configuration
  protocol https
  hec_host splunk.example.com
  hec_port 8088
  hec_token "#{ENV['SPLUNK_HEC_TOKEN']}"
  hec_endpoint services/collector
  
  # Splunk indexing parameters
  index main
  source ${tag}
  sourcetype _json
  host myapp-server-01
  
  # TLS/SSL configuration
  insecure_ssl false
  require_ssl_min_version true  # Enforces TLS 1.2+
  ca_file /path/to/ca_bundle.crt
  # client_cert /path/to/client.crt
  # client_key /path/to/client.key
  
  # Performance tuning
  gzip_compression true
  idle_timeout 5
  open_timeout 10
  read_timeout 10
  
  # Error handling
  consume_chunk_on_4xx_errors true
  coerce_to_utf8 true
  non_utf8_replacement_string " "
  
  # Custom headers
  <custom_headers>
    X-Custom-Header value
  </custom_headers>
  
  # Index-time fields
  <fields>
    environment production
    application myapp
  </fields>
</match>
```

### Sending Metrics

To send metrics to a Splunk metrics index (Splunk 7.0+):

```xml
<match metrics.**>
  @type splunk_hec_radiant
  data_type metric
  hec_host splunk.example.com
  hec_token "#{ENV['SPLUNK_HEC_TOKEN']}"
  index metrics_index
</match>
```

#### Metrics from Event Fields

```xml
<match metrics.**>
  @type splunk_hec_radiant
  data_type metric
  hec_host splunk.example.com
  hec_token "#{ENV['SPLUNK_HEC_TOKEN']}"
  
  metrics_from_event false
  metric_name_key metric_name
  metric_value_key metric_value
</match>
```

## Configuration Parameters

### HEC Connection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `protocol` | enum | `https` | Protocol to use (`http` or `https`) |
| `hec_host` | string | - | Splunk HEC hostname or IP (required) |
| `hec_port` | integer | `8088` | Splunk HEC port |
| `hec_token` | string | - | HEC token (required, secret) |
| `hec_endpoint` | string | `services/collector` | HEC API endpoint path |
| `full_url` | string | - | Full HEC URL (alternative to host+port) |

### TLS/SSL

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `insecure_ssl` | bool | `false` | Allow insecure SSL connections |
| `require_ssl_min_version` | bool | `true` | Require TLS 1.2+ |
| `ca_file` | string | - | Path to CA certificate file |
| `ca_path` | string | - | Path to CA certificates directory |
| `client_cert` | string | - | Path to client certificate |
| `client_key` | string | - | Path to client private key |
| `ssl_ciphers` | array | - | List of allowed SSL ciphers |

### Splunk Indexing

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `data_type` | enum | `event` | Data type (`event` or `metric`) |
| `index` | string | - | Splunk index name |
| `index_key` | string | - | Field name containing index |
| `host` | string | hostname | Event host field |
| `host_key` | string | - | Field name containing host |
| `source` | string | - | Event source field |
| `source_key` | string | - | Field name containing source |
| `sourcetype` | string | - | Event sourcetype field |
| `sourcetype_key` | string | - | Field name containing sourcetype |
| `time_key` | string | - | Field name containing event time |

### Performance

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gzip_compression` | bool | `false` | Enable gzip compression |
| `idle_timeout` | integer | `5` | Connection idle timeout (seconds) |
| `open_timeout` | integer | - | Connection open timeout (seconds) |
| `read_timeout` | integer | - | Read timeout (seconds) |

### Other

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keep_keys` | bool | `false` | Keep extracted key fields in event |
| `coerce_to_utf8` | bool | `true` | Replace non-UTF-8 characters |
| `non_utf8_replacement_string` | string | `" "` | Replacement for non-UTF-8 chars |
| `consume_chunk_on_4xx_errors` | bool | `true` | Consume chunks on 4xx errors |
| `custom_headers` | hash | `{}` | Custom HTTP headers |

## Migration from fluent-plugin-splunk-hec

This plugin is designed as a **drop-in replacement** for the original `fluent-plugin-splunk-hec`. To migrate:

1. **Update your Gemfile or installation**:
   ```ruby
   # Old
   # gem "fluent-plugin-splunk-hec"
   
   # New
   gem "fluent-plugin-splunk-hec-radiant"
   ```

2. **Update your Fluentd configuration**:
   ```xml
   <match **>
     # Old
     # @type splunk_hec
     
     # New
     @type splunk_hec_radiant
     
     # ... rest of configuration remains the same
   </match>
   ```

3. **Verify Ruby version**: Ensure you're running Ruby 3.0 or newer.

### Breaking Changes

- **Ruby 2.x is no longer supported** - Ruby 3.0+ is required
- **TLS 1.0/1.1 disabled by default** - TLS 1.2+ is enforced when `require_ssl_min_version` is true
- **Dependency changes**: Uses `oj` instead of `multi_json` (transparent to users)

## Development

### Prerequisites

- Ruby 3.0 or newer
- Bundler 2.0+
- Git

### Setup

```bash
git clone https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant.git
cd fluent-plugin-splunk-hec-radiant
bundle install
```

### Running Tests

```bash
bundle exec rspec
```

### Linting

```bash
bundle exec rubocop
```

### Building the Gem

```bash
bundle exec rake build
```

The gem will be created in the `pkg/` directory.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- Tests pass (`bundle exec rspec`)
- Code passes linting (`bundle exec rubocop`)
- New features include tests
- Documentation is updated

## License

Copyright 2025 G. Rahul Nutakki
Copyright 2018 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Attribution

This project is a derivative work of [fluent-plugin-splunk-hec](https://github.com/splunk/fluentd-hec) by Splunk Inc., which has reached end-of-support. See [NOTICE](NOTICE) for full attribution details.

## Support

- **Issues**: [GitHub Issues](https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant/issues)
- **Documentation**: [README.md](https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant/blob/main/README.md)
- **Original Plugin**: [Splunk fluentd-hec](https://github.com/splunk/fluentd-hec) (deprecated)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
