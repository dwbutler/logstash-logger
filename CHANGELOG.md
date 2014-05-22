0.4.1
-----
- Fixed support for `LogStash::Event` v1 format when logging a hash. Extra data
now goes to the top level instead of into the `@fields` key.

0.4.0
-----
- Support for new `LogStash::Event` v1 format. v0 is supported in 0.3+.

0.3.0
-----
- Added support for logging to a UDP listener.

0.2.1
-----
- Fixed to use Logstash's default time format for timestamps.

0.2.0
-----
- Better use of Ruby Logger's built-in LogDevice.

0.1.0
-----
- Initial release. Support for logging to a TCP listener.