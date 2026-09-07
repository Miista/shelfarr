# frozen_string_literal: true

require "test_helper"

class IndexerClients::ProwlarrSeedCriteriaTest < ActiveSupport::TestCase
  setup do
    SettingsService.set(:prowlarr_url, "http://localhost:9696")
    SettingsService.set(:prowlarr_api_key, "prowlarr-api-key")
    SettingsService.set(:prowlarr_tags, "")
  end

  teardown do
    IndexerClients::Prowlarr.reset_connection!
  end

  test "seed_criteria reads ratio and seed time configured on the indexer" do
    stub_indexers([
      indexer_definition(id: 17, name: "Superbits", seed_ratio: 1.1, seed_time: 4320)
    ])

    criteria = IndexerClients::Prowlarr.seed_criteria(17)

    assert_equal 1.1, criteria[:ratio]
    assert_equal 4320, criteria[:seed_time]
  end

  test "seed_criteria returns nil when the indexer configures no seed rules" do
    stub_indexers([ indexer_definition(id: 6, name: "LimeTorrents") ])

    assert_nil IndexerClients::Prowlarr.seed_criteria(6)
  end

  test "seed_criteria returns nil for an unknown indexer id" do
    stub_indexers([
      indexer_definition(id: 17, name: "Superbits", seed_ratio: 1.1, seed_time: 4320)
    ])

    assert_nil IndexerClients::Prowlarr.seed_criteria(999)
  end

  test "seed_criteria returns nil when the indexer id is blank" do
    assert_nil IndexerClients::Prowlarr.seed_criteria(nil)
    assert_nil IndexerClients::Prowlarr.seed_criteria("")
  end

  test "seed_criteria ignores empty field values so client defaults are kept" do
    stub_indexers([
      indexer_definition(id: 18, name: "MyAnonamouse", seed_ratio: nil, seed_time: 10080)
    ])

    criteria = IndexerClients::Prowlarr.seed_criteria(18)

    assert_nil criteria[:ratio]
    assert_equal 10080, criteria[:seed_time]
  end

  test "seed_criteria returns nil when prowlarr cannot be reached" do
    stub_request(:get, "http://localhost:9696/api/v1/indexer")
      .to_return(status: 500, body: "boom")

    assert_nil IndexerClients::Prowlarr.seed_criteria(17)
  end

  private

  def stub_indexers(definitions)
    stub_request(:get, "http://localhost:9696/api/v1/indexer")
      .to_return(
        status: 200,
        body: definitions.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Mirrors Prowlarr's shape: a flat fields array where an unset setting simply
  # carries no "value" key at all.
  def indexer_definition(id:, name:, seed_ratio: nil, seed_time: nil)
    fields = []
    fields << field("torrentBaseSettings.seedRatio", seed_ratio)
    fields << field("torrentBaseSettings.seedTime", seed_time)

    { "id" => id, "name" => name, "enable" => true, "tags" => [], "fields" => fields }
  end

  def field(name, value)
    value.nil? ? { "name" => name } : { "name" => name, "value" => value }
  end
end
