# frozen_string_literal: true

# Compatibility loader for Fluentd output plugin type `splunk_hec`.
#
# Fluentd resolves `@type splunk_hec` by requiring:
#   "fluent/plugin/out_splunk_hec"
# The radiant plugin implementation lives in:
#   "fluent/plugin/out_splunk_hec_radiant"
#
# This file simply bridges the conventional name to the radiant implementation.

require "fluent/plugin/out_splunk_hec_radiant"
