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

  header = {
    alg: "ES256",
    kid: key_id,
    typ: "JWT"
  }
  payload = {
    iss: issuer_id,
    exp: Time.now.to_i + (20 * 60),
    aud: "appstoreconnect-v1"
  }

  signing_input = "#{base64url(header.to_json)}.#{base64url(payload.to_json)}"
  der_signature = private_key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
  signature_parts = OpenSSL::ASN1.decode(der_signature).value.map do |integer|
    integer.value.to_s(2).rjust(32, "\x00")[-32, 32]
  end
  signature = signature_parts.join
  "#{signing_input}.#{base64url(signature)}"
end

def request(method, path, token, body = nil)
  uri = URI("#{API_BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  klass = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch
  }.fetch(method)
  request = klass.new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(body) if body

  response = http.request(request)
  parsed = response.body && !response.body.empty? ? JSON.parse(response.body) : {}
  unless response.code.to_i.between?(200, 299)
    warn JSON.pretty_generate(parsed)
    abort "App Store Connect API failed: #{method.to_s.upcase} #{path} -> #{response.code}"
  end

  parsed
end

LOCALIZATIONS = {
  "en-US" => {
    name: "Fitgram Pro Monthly",
    description: "Unlimited AI checks, Ola coach and premium tools."
  },
  "pl" => {
    name: "Fitgram Pro miesięcznie",
    description: "AI bez limitu, Ola i narzędzia premium."
  },
  "ru" => {
    name: "Fitgram Pro на месяц",
    description: "AI без лимита, Оля и премиум-инструменты."
  },
  "uk" => {
    name: "Fitgram Pro на місяць",
    description: "AI без ліміту, Оля і преміум-інструменти."
  },
  "es-ES" => {
    name: "Fitgram Pro mensual",
    description: "IA sin límites, Ola y herramientas premium."
  }
}.freeze

load_env_file(ENV_FILE)

subscription_id = ARGV.fetch(0) do
  ENV.fetch("APP_STORE_SUBSCRIPTION_ID", "6805221991")
end

token = asc_token
existing = request(:get, "/v1/subscriptions/#{subscription_id}/subscriptionLocalizations?limit=200", token)
by_locale = existing.fetch("data", []).to_h do |localization|
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
          attributes: {
            name: copy.fetch(:name),
            description: copy.fetch(:description)
          }
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
          attributes: {
            name: copy.fetch(:name),
            locale: locale,
            description: copy.fetch(:description)
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
    puts "Created #{locale}"
  end
end

puts "Done."
