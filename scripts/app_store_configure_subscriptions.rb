#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
ENV_FILE = File.join(ROOT, ".env.fastlane")
API_BASE = "https://api.appstoreconnect.apple.com"
MONTHLY_ID = "6805221991"
YEARLY_ID = "6805224123"
PAYWALL_SCREENSHOT = File.join(ROOT, "fastlane", "screenshots", "en-US", "6_iPhone_69_goal.png")

def load_env_file(path)
  return unless File.exist?(path)

  File.readlines(path, chomp: true).each do |line|
    next if line.strip.empty? || line.strip.start_with?("#")

    key, value = line.split("=", 2)
    next if key.nil? || value.nil?

    ENV[key.strip] ||= value.strip.gsub(/\A["']|["']\z/, "")
  end
end

def base64url(payload)
  [payload].pack("m0").tr("+/", "-_").delete("=")
end

def asc_token
  key_id = ENV.fetch("APP_STORE_CONNECT_API_KEY_ID")
  issuer_id = ENV.fetch("APP_STORE_CONNECT_API_ISSUER_ID")
  key_path = File.expand_path(ENV.fetch("APP_STORE_CONNECT_API_KEY_PATH"))
  private_key = OpenSSL::PKey::EC.new(File.read(key_path))

  header = { alg: "ES256", kid: key_id, typ: "JWT" }
  payload = { iss: issuer_id, exp: Time.now.to_i + (20 * 60), aud: "appstoreconnect-v1" }
  signing_input = "#{base64url(header.to_json)}.#{base64url(payload.to_json)}"
  der_signature = private_key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
  signature = OpenSSL::ASN1.decode(der_signature).value.map do |integer|
    integer.value.to_s(2).rjust(32, "\x00")[-32, 32]
  end.join
  "#{signing_input}.#{base64url(signature)}"
end

def request(method, path, token, body = nil, options = {})
  allow_conflict = options.fetch(:allow_conflict, false)
  uri = URI("#{API_BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  klass = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch,
    delete: Net::HTTP::Delete
  }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body

  response = http.request(req)
  parsed = response.body && !response.body.empty? ? JSON.parse(response.body) : {}
  return parsed if allow_conflict && response.code.to_i == 409

  unless response.code.to_i.between?(200, 299)
    warn JSON.pretty_generate(parsed)
    abort "App Store Connect API failed: #{method.to_s.upcase} #{path} -> #{response.code}"
  end

  parsed
end

def upload_request(operation, bytes)
  uri = URI(operation.fetch("url"))
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Put.new(uri)
  operation.fetch("requestHeaders", []).each do |header|
    req[header.fetch("name")] = header.fetch("value")
  end
  offset = operation.fetch("offset", 0)
  length = operation.fetch("length", bytes.bytesize)
  req.body = bytes.byteslice(offset, length)

  response = http.request(req)
  unless response.code.to_i.between?(200, 299)
    abort "Asset upload failed: #{response.code} #{response.body}"
  end
end

def all_territories(token)
  territories = []
  path = "/v1/territories?limit=200"
  loop do
    response = request(:get, path, token)
    territories.concat(response.fetch("data").map { |entry| { type: "territories", id: entry.fetch("id") } })
    next_link = response.dig("links", "next")
    break unless next_link

    path = URI(next_link).request_uri
  end
  territories
end

def ensure_subscription_availability(subscription_id, territories, token)
  body = {
    data: {
      type: "subscriptionAvailabilities",
      attributes: {
        availableInNewTerritories: true
      },
      relationships: {
        subscription: {
          data: {
            type: "subscriptions",
            id: subscription_id
          }
        },
        availableTerritories: {
          data: territories
        }
      }
    }
  }

  result = request(:post, "/v1/subscriptionAvailabilities", token, body, { allow_conflict: true })
  if result.fetch("errors", []).any?
    puts "Availability already configured or requires UI for #{subscription_id}"
  else
    puts "Availability created for #{subscription_id}"
  end
end

def price_point(subscription_id, territory, desired_price, token)
  points = []
  path = "/v1/subscriptions/#{subscription_id}/pricePoints?filter[territory]=#{territory}&limit=200"
  loop do
    response = request(:get, path, token)
    points.concat(response.fetch("data"))
    next_link = response.dig("links", "next")
    break unless next_link

    path = URI(next_link).request_uri
  end
  chosen = points.find do |entry|
    entry.dig("attributes", "customerPrice").to_f == desired_price
  end
  chosen ||= points.min_by do |entry|
    (entry.dig("attributes", "customerPrice").to_f - desired_price).abs
  end
  abort "No price point found for #{subscription_id}" unless chosen

  chosen
end

def set_price(subscription_id, price_point_id, plan_type, token)
  current = request(:get, "/v1/subscriptions/#{subscription_id}/prices?limit=200", token)
    .fetch("data", [])
    .any? { |entry| entry.dig("relationships", "subscriptionPricePoint", "data", "id") == price_point_id }
  if current
    puts "Price already configured for #{subscription_id}"
    return
  end

  request(
    :post,
    "/v1/subscriptionPrices",
    token,
    {
      data: {
        type: "subscriptionPrices",
        attributes: {
          startDate: nil,
          planType: plan_type
        },
        relationships: {
          subscription: {
            data: {
              type: "subscriptions",
              id: subscription_id
            }
          },
          subscriptionPricePoint: {
            data: {
              type: "subscriptionPricePoints",
              id: price_point_id
            }
          }
        }
      }
    },
    { allow_conflict: true }
  )
  puts "Price configured for #{subscription_id}"
end

def ensure_trial(subscription_id, token)
  existing = request(:get, "/v1/subscriptions/#{subscription_id}/introductoryOffers?limit=200&filter[territory]=USA", token)
    .fetch("data", [])
    .find do |entry|
      entry.dig("attributes", "offerMode") == "FREE_TRIAL" &&
        entry.dig("attributes", "duration") == "ONE_WEEK"
    end
  if existing
    puts "Trial already exists for #{subscription_id}"
    return
  end

  request(
    :post,
    "/v1/subscriptionIntroductoryOffers",
    token,
    {
      data: {
        type: "subscriptionIntroductoryOffers",
        attributes: {
          startDate: nil,
          endDate: nil,
          duration: "ONE_WEEK",
          offerMode: "FREE_TRIAL",
          numberOfPeriods: 1,
          targetSubscriptionPlanType: "MONTHLY"
        },
        relationships: {
          subscription: {
            data: {
              type: "subscriptions",
              id: subscription_id
            }
          },
          territory: {
            data: {
              type: "territories",
              id: "USA"
            }
          }
        }
      }
    },
    { allow_conflict: true }
  )
  puts "Trial configured for #{subscription_id}"
end

def upload_review_screenshot(subscription_id, token)
  return puts("Screenshot source not found, skipped") unless File.exist?(PAYWALL_SCREENSHOT)

  existing = request(:get, "/v1/subscriptions/#{subscription_id}?include=appStoreReviewScreenshot", token)
    .fetch("included", [])
    .find { |entry| entry.fetch("type") == "subscriptionAppStoreReviewScreenshots" }
  if existing && existing.dig("attributes", "assetDeliveryState", "state") != "FAILED"
    puts "Review screenshot already exists for #{subscription_id}"
    return
  end

  bytes = File.binread(PAYWALL_SCREENSHOT)
  file_name = "fitgram-paywall-review.png"
  created = request(
    :post,
    "/v1/subscriptionAppStoreReviewScreenshots",
    token,
    {
      data: {
        type: "subscriptionAppStoreReviewScreenshots",
        attributes: {
          fileSize: bytes.bytesize,
          fileName: file_name
        },
        relationships: {
          subscription: {
            data: {
              type: "subscriptions",
              id: subscription_id
            }
          }
        }
      }
    }
  )
  screenshot = created.fetch("data")
  screenshot.fetch("attributes").fetch("uploadOperations").each do |operation|
    upload_request(operation, bytes)
  end
  request(
    :patch,
    "/v1/subscriptionAppStoreReviewScreenshots/#{screenshot.fetch("id")}",
    token,
    {
      data: {
        type: "subscriptionAppStoreReviewScreenshots",
        id: screenshot.fetch("id"),
        attributes: {
          uploaded: true,
          sourceFileChecksum: Digest::MD5.file(PAYWALL_SCREENSHOT).hexdigest
        }
      }
    }
  )
  puts "Review screenshot uploaded for #{subscription_id}"
end

load_env_file(ENV_FILE)
token = asc_token
territories = all_territories(token)

monthly_price = price_point(MONTHLY_ID, "USA", 9.99, token)
yearly_price = price_point(YEARLY_ID, "USA", 59.99, token)
puts "Monthly price point: #{monthly_price.fetch("id")} ($#{monthly_price.dig("attributes", "customerPrice")})"
puts "Yearly price point: #{yearly_price.fetch("id")} ($#{yearly_price.dig("attributes", "customerPrice")})"

ensure_subscription_availability(MONTHLY_ID, territories, token)
ensure_subscription_availability(YEARLY_ID, territories, token)
set_price(MONTHLY_ID, monthly_price.fetch("id"), "MONTHLY", token)
set_price(YEARLY_ID, yearly_price.fetch("id"), "MONTHLY", token)
ensure_trial(MONTHLY_ID, token)
ensure_trial(YEARLY_ID, token)
upload_review_screenshot(MONTHLY_ID, token)
upload_review_screenshot(YEARLY_ID, token)

puts "Done."
