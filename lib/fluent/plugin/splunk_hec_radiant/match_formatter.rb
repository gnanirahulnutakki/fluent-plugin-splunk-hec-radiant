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

require "fluent/match"

module Fluent
  module Plugin
    module SplunkHecRadiant
      # Helper class for pattern-based formatting
      class MatchFormatter
        def initialize(pattern, formatter)
          # based on fluentd/lib/fluent/event_router.rb
          patterns = pattern.split(/\s+/).map do |str|
            Fluent::MatchPattern.create(str)
          end
          @pattern =
            if patterns.length == 1
              patterns[0]
            else
              Fluent::OrMatchPattern.new(patterns)
            end
          @formatter = formatter
        end

        def match?(tag)
          @pattern.match tag
        end

        def format(tag, time, record)
          @formatter.format tag, time, record
        end
      end
    end
  end
end
