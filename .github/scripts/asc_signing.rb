# Creates (setup) and removes (cleanup) a temporary App Store distribution certificate and
# provisioning profiles through the App Store Connect API, so CI needs no Mac and no stored
# certificate. Revoking a distribution certificate does not affect builds already uploaded.
#
#   ruby asc_signing.rb setup   # needs KEY_ID, ISSUER_ID, KEY_PATH, RUNNER_TEMP, GITHUB_RUN_NUMBER
#   ruby asc_signing.rb cleanup
#
# Bundle IDs to sign come from BUNDLE_IDS (comma-separated).

require "openssl"
require "json"
require "net/http"
require "base64"
require "uri"

API = "https://api.appstoreconnect.apple.com/v1"
TMP = ENV.fetch("RUNNER_TEMP")
STATE = File.join(TMP, "asc_signing_state.json")

def b64url(data)
  Base64.urlsafe_encode64(data, padding: false)
end

def token
  key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("KEY_PATH")))
  header = { alg: "ES256", kid: ENV.fetch("KEY_ID"), typ: "JWT" }
  now = Time.now.to_i
  payload = { iss: ENV.fetch("ISSUER_ID"), iat: now, exp: now + 1100, aud: "appstoreconnect-v1" }
  input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"
  der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
  r, s = OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\x00")[-32..] }
  "#{input}.#{b64url(r + s)}"
end

def api(method, path, body = nil)
  uri = URI(path.start_with?("http") ? path : API + path)
  req = Net::HTTP.const_get(method.capitalize).new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  unless res.is_a?(Net::HTTPSuccess)
    raise "App Store Connect API #{method} #{uri.path} failed (#{res.code}): #{res.body}"
  end
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

def sh(cmd)
  system(cmd) or abort "Command failed: #{cmd.split(' -p ').first}"
end

def setup
  run = ENV.fetch("GITHUB_RUN_NUMBER", "0")
  bundle_ids = ENV.fetch("BUNDLE_IDS").split(",").map(&:strip)

  # 1. Private key + CSR, then a distribution certificate.
  key = OpenSSL::PKey::RSA.generate(2048)
  csr = OpenSSL::X509::Request.new
  csr.subject = OpenSSL::X509::Name.parse("/CN=Onestep CI #{run}")
  csr.public_key = key
  csr.sign(key, OpenSSL::Digest::SHA256.new)
  cert = api(:post, "/certificates", data: {
    type: "certificates",
    attributes: { csrContent: Base64.strict_encode64(csr.to_der), certificateType: "DISTRIBUTION" },
  })["data"]
  state = { "certificate" => cert["id"], "profiles" => [] }
  File.write(STATE, state.to_json)

  # 2. Keychain with the identity.
  x509 = OpenSSL::X509::Certificate.new(Base64.decode64(cert["attributes"]["certificateContent"]))
  key_path = File.join(TMP, "dist.key.pem")
  cert_path = File.join(TMP, "dist.cer")
  File.write(key_path, key.to_pem)
  File.binwrite(cert_path, x509.to_der)
  kc = File.join(TMP, "signing.keychain-db")
  pw = "ci-#{run}"
  sh "security create-keychain -p #{pw} #{kc}"
  sh "security set-keychain-settings -lut 21600 #{kc}"
  sh "security unlock-keychain -p #{pw} #{kc}"
  sh "security import #{key_path} -k #{kc} -T /usr/bin/codesign -T /usr/bin/security"
  sh "security import #{cert_path} -k #{kc}"
  wwdr = File.join(TMP, "AppleWWDRCAG3.cer")
  sh "curl -fsSL -o #{wwdr} https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
  system("security import #{wwdr} -k #{kc}") # may already be trusted system-wide
  sh "security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k #{pw} #{kc} > /dev/null"
  sh "security list-keychains -d user -s #{kc} $(security list-keychains -d user | tr -d '\"')"
  File.delete(key_path)

  # 3. An App Store profile per bundle ID.
  dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
  Dir.mkdir(File.dirname(dir)) unless Dir.exist?(File.dirname(dir))
  Dir.mkdir(dir) unless Dir.exist?(dir)
  mapping = {}
  bundle_ids.each do |identifier|
    found = api(:get, "/bundleIds?filter[identifier]=#{identifier}&limit=200")["data"]
              .find { |b| b["attributes"]["identifier"] == identifier }
    abort "Bundle ID #{identifier} is not registered in the developer portal" unless found
    name = "Onestep CI #{run} #{identifier}"
    profile = api(:post, "/profiles", data: {
      type: "profiles",
      attributes: { name: name, profileType: "IOS_APP_STORE" },
      relationships: {
        bundleId: { data: { type: "bundleIds", id: found["id"] } },
        certificates: { data: [{ type: "certificates", id: cert["id"] }] },
      },
    })["data"]
    state["profiles"] << profile["id"]
    File.write(STATE, state.to_json)
    uuid = profile["attributes"]["uuid"]
    File.binwrite(File.join(dir, "#{uuid}.mobileprovision"), Base64.decode64(profile["attributes"]["profileContent"]))
    mapping[identifier] = name
  end

  # 4. Export options for manual signing.
  profiles_xml = mapping.map { |id, name| "<key>#{id}</key><string>#{name}</string>" }.join
  File.write(File.join(TMP, "ExportOptions.plist"), <<~PLIST)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>method</key><string>app-store-connect</string>
      <key>destination</key><string>export</string>
      <key>teamID</key><string>#{ENV.fetch("TEAM_ID")}</string>
      <key>signingStyle</key><string>manual</string>
      <key>signingCertificate</key><string>Apple Distribution</string>
      <key>provisioningProfiles</key><dict>#{profiles_xml}</dict>
      <key>manageAppVersionAndBuildNumber</key><false/>
    </dict></plist>
  PLIST
  puts "Signing ready: certificate #{cert['id']}, profiles #{mapping.values.join(', ')}"
end

def cleanup
  return puts("Nothing to clean up") unless File.exist?(STATE)
  state = JSON.parse(File.read(STATE))
  state["profiles"].each { |id| api(:delete, "/profiles/#{id}") rescue warn("Could not delete profile #{id}") }
  api(:delete, "/certificates/#{state['certificate']}") rescue warn("Could not revoke certificate")
  system("security delete-keychain #{File.join(TMP, 'signing.keychain-db')}")
  puts "Temporary certificate revoked and profiles deleted"
end

case ARGV[0]
when "setup" then setup
when "cleanup" then cleanup
else abort "usage: asc_signing.rb setup|cleanup"
end
