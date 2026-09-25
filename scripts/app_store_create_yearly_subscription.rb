#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
ENV_FILE = File.join(ROOT, ".env.fastlane")
API_BASE = "https://api.appstoreconnect.apple.com"

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

def request(method, path, token, body = nil)
  uri = URI("#{API_BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body

  response = http.request(req)
  parsed = response.body && !response.body.empty? ? JSON.parse(response.body) : {}
  unless response.code.to_i.between?(200, 299)
    warn JSON.pretty_generate(parsed)
    abort "App Store Connect API failed: #{method.to_s.upcase} #{path} -> #{response.code}"
  end
  parsed
end

def find_existing_subscription(token, product_id)
  # Filter by productId is not consistently documented for every API version,
  # so use the app-scoped list from the monthly subscription's group below.
  nil
end

LOCALIZATIONS = {
  "en-US" => {
    name: "Fitgram Pro Yearly",
    description: "Best value: AI checks, Ola coach and premium tools."
  },
  "pl" => {
    name: "Fitgram Pro rocznie",
    description: "Najlepsza cena: AI bez limitu, Ola i premium."
  },
  "ru" => {
    name: "Fitgram Pro на год",
    description: "Лучшее: AI без лимита, Оля и премиум."
  },
  "uk" => {
    name: "Fitgram Pro на рік",
    description: "Найкраще: AI без ліміту, Оля і преміум."
  },
  "es-ES" => {
    name: "Fitgram Pro anual",
    description: "Mejor precio: IA sin límites, Ola y premium."
  }
}.freeze

load_env_file(ENV_FILE)

monthly_subscription_id = ARGV.fetch(0, "6805221991")
yearly_product_id = ARGV.fetch(1, "fitgram_premium_yearly")
token = asc_token

monthly = request(:get, "/v1/subscriptions/#{monthly_subscription_id}?include=group", token)
group_id = monthly.fetch("included").find { |entry| entry.fetch("type") == "subscriptionGroups" }.fetch("id")

group_subscriptions = request(:get, "/v1/subscriptionGroups/#{group_id}/subscriptions?limit=200", token)
existing = group_subscriptions.fetch("data", []).find do |subscription|
  subscription.dig("attributes", "productId") == yearly_product_id
end

if existing
  yearly_id = existing.fetch("id")
  puts "Yearly subscription already exists: #{yearly_id}"
else
  created = request(
    :post,
    "/v1/subscriptions",
    token,
    {
      data: {
        type: "subscriptions",
        attributes: {
          name: "Fitgram Pro Yearly",
          productId: yearly_product_id,
          subscriptionPeriod: "ONE_YEAR",
          familySharable: true,
          reviewNote: "This subscription unlocks Fitgram Pro for one year: unlimited AI food checks, Ola coach insights, advanced progress tools, activity-aware calorie targets, premium facts, recipes, and saved meals.",
          groupLevel: 2
        },
        relationships: {
          group: {
            data: {
              type: "subscriptionGroups",
              id: group_id
            }
          }
        }
      }
    }
  )
  yearly_id = created.fetch("data").fetch("id")
  puts "Created yearly subscription: #{yearly_id}"
end

existing_localizations = request(:get, "/v1/subscriptions/#{yearly_id}/subscriptionLocalizations?limit=200", token)
by_locale = existing_localizations.fetch("data", []).to_h do |localization|
  [localization.dig("attributes", "locale"), localization.fetch("id")]
end

LOCALIZATIONS.each do |locale, copy|
  if by_locale[locale]
    request(
      :patch,
      "/v1/subscriptionLocalizations/#{by_locale.fetch(locale)}",
      token,
      {
        data: {
          type: "subscriptionLocalizations",
          id: by_locale.fetch(locale),
          attributes: copy
        }
      }
    )
    puts "Updated #{locale}"
  else
    request(
      :post,
      "/v1/subscriptionLocalizations",
      token,
      {
        data: {
          type: "subscriptionLocalizations",
          attributes: copy.merge(locale: locale),
          relationships: {
            subscription: {
              data: {
                type: "subscriptions",
                id: yearly_id
              }
            }
          }
        }
      }
    )
    puts "Created #{locale}"
  end
end

puts "Done. Yearly subscription id: #{yearly_id}"
