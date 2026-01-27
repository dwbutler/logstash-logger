# LogStashLogger
[![Build Status](https://github.com/dwbutler/logstash-logger/workflows/Ruby%20tests/badge.svg)](https://github.com/dwbutler/logstash-logger/actions) [![Code Climate](https://codeclimate.com/github/dwbutler/logstash-logger/badges/gpa.svg)](https://codeclimate.com/github/dwbutler/logstash-logger) [![codecov.io](http://codecov.io/github/dwbutler/logstash-logger/coverage.svg?branch=master)](http://codecov.io/github/dwbutler/logstash-logger?branch=master) [![Gem Version](https://badge.fury.io/rb/logstash-logger.svg)](https://badge.fury.io/rb/logstash-logger)

LogStashLogger extends Ruby's `Logger` class to log directly to
[Logstash](https://www.elastic.co/logstash).
It supports writing to various outputs in logstash JSON format. This is an improvement over
writing to a file or syslog since Logstash can receive the structured data directly.

## Features

* Can write directly to a logstash listener over a UDP or TCP/SSL connection.
* Can write to a file, Redis, Kafka, Kinesis, Firehose, a unix socket, syslog, stdout, or stderr.
* Logger can take a string message, a hash, a `LogStash::Event`, an object, or a JSON string as input.
* Events are automatically populated with message, timestamp, host, and severity.
* Writes in logstash JSON format, but supports other formats as well.
* Can write to multiple outputs.
* Log messages are buffered and automatically re-sent if there is a connection problem.
* Easily integrates with Rails via configuration.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'logstash-logger'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install logstash-logger
```

## Ruby Compatibility

Verified to work with:

* MRI Ruby 3.2, 3.3, 3.4, 4.0
* JRuby 9.x (when compatible with Ruby 3.2+)

Ruby versions < 3.2 are EOL'ed and no longer supported.

## Documentation

* [Usage Examples](docs/usage.md) - Logger types, formatters, and URI configuration
* [Output Configuration](docs/outputs.md) - Logstash listener and HTTP setup
* [SSL/TLS](docs/ssl.md) - Secure connections and hostname verification
* [Customization](docs/customization.md) - Custom fields, silencing, and error handling
* [Buffering](docs/buffering.md) - Buffer settings, retries, and sync mode
* [Rails Integration](docs/rails.md) - Full Rails configuration guide
* [Troubleshooting](docs/troubleshooting.md) - Common issues and breaking changes

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
