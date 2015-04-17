## 0.10.1
- Fix for Redis URI parsing issue.
Fixes [#41](https://github.com/dwbutler/logstash-logger/issues/41).
Thanks [Vadim Kazakov](https://github.com/yads)!

## 0.10.0
- Support for logging to Kafka.
Fixes [#37](https://github.com/dwbutler/logstash-logger/issues/37).
Thanks [Felix Bechstein](https://github.com/felixb)!

## 0.9.0
- Support for customizing the fields on all logged messages via configuration.
Fixes [#32](https://github.com/dwbutler/logstash-logger/pull/32).
Thanks [Chris Blatchley](https://github.com/chrisblatchley)!

## 0.8.0
- Support for logging to stderr. Fixes [#24](https://github.com/dwbutler/logstash-logger/pull/25).
Thanks [Jan Schulte](https://github.com/schultyy)!
- Support multiple log outputs. Fixes [#28](https://github.com/dwbutler/logstash-logger/pull/28).
Thanks [Kurt Preston](https://github.com/KurtPreston)!

## 0.7.0
- Support for logging to a generic IO object.
- Support for overriding IO in stdout logger. Fixes [#20](https://github.com/dwbutler/logstash-logger/pull/20).
Thanks [Arron Mabrey](https://github.com/arronmabrey)!
- Support for configuring logger with a URI. See [#22](https://github.com/dwbutler/logstash-logger/pull/22).
Thanks [Arron Mabrey](https://github.com/arronmabrey)!
- Support logging any object. See [#23](https://github.com/dwbutler/logstash-logger/issues/23).

## 0.6.2
- Allow type to be specified as a string. Fixes [#19](https://github.com/dwbutler/logstash-logger/pull/19).
Thanks [Arron Mabrey](https://github.com/arronmabrey)!

## 0.6.1
- Don't mutate options passed to LogStashLogger. Fixes [#18](https://github.com/dwbutler/logstash-logger/pull/18).
Thanks [Arron Mabrey](https://github.com/arronmabrey)!

## 0.6.0
- Support for logging to a file.
- Support for logging to a Redis list.
- Support for logging to a local Unix socket.
- Railtie supports file logger, using default log path and `config.autoflush_log` configuration.
- All `LogStashLogger` types now support a `sync` option, which controls if each message is automatically flushed.

## 0.5.0
- Support for tagged logging. The interface was extracted from `ActiveSupport::TaggedLogging`
and outputs to the `tags` key. (Thanks [pctj101](https://github.com/pctj101)!)
- The `(host, port, type)` constructor has been deprecated in favor of an options hash constructor.
- Support for using SSL for TCP connections. (Thanks [Gary Rennie](https://github.com/Gazler)!)
- Support for configuring logger to write to STDOUT. (Thanks [Nick Ethier](https://github.com/nickethier)!)
- Support for Rails configuration.
- Fixed output to STDOUT in Rails console (Rails 4+).
- `host` is no longer required for TCP/UDP. It will default to `0.0.0.0`, the same default port that logstash listens on.
- Changed event key `source` to `host` to match what the latest logstash expects.
- Output event timestamp consistently even if `Time#to_json` is overridden.
- Major refactoring which will lead the way to support other log types.

## 0.4.1
- Fixed support for `LogStash::Event` v1 format when logging a hash. Extra data
now goes to the top level instead of into the `@fields` key.

## 0.4.0
- Support for new `LogStash::Event` v1 format. v0 is supported in 0.3+.

## 0.3.0
- Added support for logging to a UDP listener.

## 0.2.1
- Fixed to use Logstash's default time format for timestamps.

## 0.2.0
- Better use of Ruby Logger's built-in LogDevice.

## 0.1.0
- Initial release. Support for logging to a TCP listener.
