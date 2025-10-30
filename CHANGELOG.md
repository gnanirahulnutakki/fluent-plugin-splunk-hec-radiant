# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-31

### Added
- Initial release of fluent-plugin-splunk-hec-radiant
- Forked from fluent-plugin-splunk-hec version 1.3.3
- Ruby 3.0+ support (dropped Ruby 2.x)
- Modern dependencies:
  - Fluentd >= 1.16
  - net-http-persistent >= 4.0
  - oj ~> 3.16 (replaced multi_json)
  - prometheus-client >= 2.1.0
- Enhanced security:
  - TLS 1.2+ required by default
  - Updated SSL/TLS handling
- Improved performance with oj JSON library
- Comprehensive test coverage with RSpec
- GitHub Actions CI/CD pipeline
- RuboCop linting configuration
- Detailed documentation and examples

### Changed
- Minimum Ruby version increased from 2.3 to 3.0
- Replaced multi_json with oj for better performance
- Updated TLS minimum version from 1.1 to 1.2
- Modernized code for Ruby 3.x compatibility
- Plugin registration name changed from `splunk_hec` to `splunk_hec_radiant`
- User-Agent header updated to identify as fluent-plugin-splunk-hec-radiant

### Removed
- Removed support for Ruby 2.x
- Removed support for TLS 1.0 and 1.1 by default

## [Unreleased]

### Planned
- Additional test coverage
- Performance benchmarks
- Example configurations for common use cases
- Integration tests with mock Splunk HEC server
- Documentation improvements

---

## Upstream History

This plugin is based on [fluent-plugin-splunk-hec](https://github.com/splunk/fluentd-hec) version 1.3.3 by Splunk Inc.

For upstream changelog history, see: https://github.com/splunk/fluentd-hec/releases
