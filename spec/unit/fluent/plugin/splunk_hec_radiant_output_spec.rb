# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fluent::Plugin::SplunkHecRadiantOutput do
  let(:driver) { Fluent::Test::Driver::Output.new(described_class).configure(config) }
  let(:config) do
    <<~CONF
      hec_host splunk.example.com
      hec_token test-token-1234
    CONF
  end

  describe "#configure" do
    it "configures with minimum required parameters" do
      expect { driver }.not_to raise_error
    end

    context "when hec_host and full_url are both missing" do
      let(:config) do
        <<~CONF
          hec_token test-token-1234
        CONF
      end

      it "raises configuration error" do
        expect { driver }.to raise_error(Fluent::ConfigError, /One of `hec_host` or `full_url` is required/)
      end
    end

    context "when hec_token is missing" do
      let(:config) do
        <<~CONF
          hec_host splunk.example.com
        CONF
      end

      it "raises configuration error" do
        expect { driver }.to raise_error(Fluent::ConfigError)
      end
    end
  end

  describe "#format" do
    let(:time) { Fluent::EventTime.parse("2025-01-01 12:00:00 UTC") }
    let(:record) { { "message" => "test log", "level" => "info" } }

    before do
      driver.run
    end

    it "formats event correctly" do
      formatted = driver.instance.format("test.tag", time, record.dup)
      parsed = Oj.load(formatted)

      expect(parsed).to include("event", "host", "time")
      expect(parsed["host"]).to be_a(String)
      expect(parsed["time"]).to be_a(String)
      # Event is the formatted record (may be stringified by formatter)
      expect(parsed["event"]).to be_a(Hash).or(be_a(String))
    end
  end

  describe "version" do
    it "has a version number" do
      expect(Fluent::Plugin::SplunkHecRadiant::VERSION).not_to be_nil
      expect(Fluent::Plugin::SplunkHecRadiant::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
