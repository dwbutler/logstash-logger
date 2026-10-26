require 'openssl'
require 'tempfile'

# Builds throwaway self-signed certificates for TLS specs. Nothing is written
# outside Tempfile, and the keys never leave the test process.
module TLSHelper
  def self.self_signed(common_name: 'localhost', dns: ['localhost'], ips: ['127.0.0.1'])
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = rand(2**64)
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=#{common_name}")
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    ef = OpenSSL::X509::ExtensionFactory.new(cert, cert)
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
    sans = dns.map { |d| "DNS:#{d}" } + ips.map { |i| "IP:#{i}" }
    cert.add_extension(ef.create_extension('subjectAltName', sans.join(','))) unless sans.empty?
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end

  def self.cert_file(cert)
    Tempfile.new(['logstash-logger-test', '.crt']).tap do |f|
      f.write(cert.to_pem)
      f.flush
    end
  end
end
