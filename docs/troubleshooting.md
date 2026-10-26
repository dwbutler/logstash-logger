# Troubleshooting

## Logstash never receives any logs

If you are using a device backed by a Ruby IO object (such as a file, UDP socket, or TCP socket), please be aware that Ruby
keeps its own internal buffer. Despite the fact that LogStashLogger buffers
messages and flushes them periodically, the data written to the IO object can
be buffered by Ruby internally indefinitely, and may not even write until the
program terminates. If this bothers you or you need to see log messages
immediately, your only recourse is to set the `sync: true` option.

## JSON::GeneratorError

Your application is probably attempting to log data that is not encoded in a valid way. When this happens, Ruby's
standard JSON library will raise an exception. You may be able to overcome this by swapping out a different JSON encoder
such as Oj. Use the [oj_mimic_json](https://github.com/ohler55/oj_mimic_json) gem to use Oj for JSON generation.

## Records tagged `_logstashlogger_format_failure`

When a log call cannot be turned into a record, for example because a logged
value cannot be serialized to JSON, LogStashLogger writes a placeholder record
instead. It is framed like any other record, so the records around it are not
affected. The placeholder has the message `Failed to format log event`, the
tag `_logstashlogger_format_failure`, the logger's time and severity, and the
error class in an `error` field. The error itself is reported to the error
logger. Before 1.1.0 a bare `Failed to format log event` string was written
without a line ending, which could merge with the next record.

## The `cee_syslog` header shows the local hostname

The `cee_syslog` formatter writes a `hostname progname:@cee:` header before
each record. The hostname is always this machine's hostname, and control
characters in the header are replaced with spaces. A `host` field in the logged
content, or one set in `customize_event`, appears only in the JSON body.

## No logs getting sent on Heroku

Heroku recommends installing the [rails_12factor](https://github.com/heroku/rails_12factor) so that logs get sent to STDOUT.
Unfortunately, this overrides LogStashLogger, preventing logs from being sent to their configured destination. The solution
is to remove `rails_12factor` from your Gemfile.

## Logging eventually stops in production

This is most likely not a problem with LogStashLogger, but rather a different gem changing the log level of `Rails.logger`.
This is especially likely if you're using a threaded server such as Puma, since gems often change the log level of
`Rails.logger` in a non thread-safe way. See [#17](https://github.com/dwbutler/logstash-logger/issues/17) for more information.

## Sometimes two lines of JSON log messages get sent as one message

If you're using UDP output and writing to a logstash listener, you are most likely encountering a bug in the UDP implementation
of the logstash listener. There is no known fix at this time. See [#43](https://github.com/dwbutler/logstash-logger/issues/43)
for more information.

## Errno::EMSGSIZE - Message too long

The UDP output sends each record as one datagram, and a datagram has a size
limit: 65,507 bytes for IPv4, and less on some hosts (macOS allows 9,216 bytes
by default). The UDP output replaces any formatted record larger than
`max_datagram_size` (65,507 bytes by default) with a small record that has the
message `Record of N bytes replaced: too large for one UDP datagram`, the tag
`_logstashlogger_record_too_large` and an `original_size` field. The error
logger gets the size, never the content. If your host or collector accepts
smaller datagrams, set `max_datagram_size` (at least 512) to its limit:

```ruby
logger = LogStashLogger.new(type: :udp, host: 'localhost', port: 5228, max_datagram_size: 9216)
```

`max_message_size` truncates only the `message` field, so it cannot keep a
record under the datagram limit on its own:

```ruby
LogStashLogger.configure do |config|
  config.max_message_size = 2000
end
```

Other fields are never truncated. A logged Hash can carry fields of any size,
and a logged String that starts with `{` is parsed as JSON into fields, so text
that your application logs as is (such as a request body) can put a large value
in a field other than `message`. If records must arrive whole, use the TCP
output, which has no per-record limit.

The opt-in `max_record_bytes` option (see [Buffering](buffering.md)) is checked
first, when a record is logged, and drops a record over it without a
replacement.

# Breaking changes

## Version 1.1+

MRI Ruby < 3.3 and Rails < 8.0 are no longer supported, since they have been EOL'ed. If you are on Ruby 3.2 or Rails 7.2, you will need to use 1.0.x.

## Version 0.27+

MRI Ruby < 3.2 is no longer supported, since it has been EOL'ed. If you are on an older version of Ruby, you will need to use 0.26 or below.

## Version 0.25+

Rails 3.2, MRI Ruby < 2.2, and JRuby 1.7 are no longer supported, since they have been
EOL'ed. If you are on an older version of Ruby, you will need to use 0.24 or below.

## Version 0.5+

* The `source` event key has been replaced with `host` to better match the latest logstash.
* The `(host, port, type)` constructor has been deprecated in favor of an options hash constructor.

## Version 0.4+

`LogStash::Event` uses the v1 format starting version 1.2+. If you're using the v1, you'll need to install
LogStashLogger version 0.4+. This is not backwards compatible with the old `LogStash::Event` v1.1.5, which uses
the v0 format.

## Version 0.3+

Earlier versions of this gem (<= 0.2.1) only implemented a TCP connection.
Newer versions (>= 0.3) also implement UDP, and use that as the new default.
Please be aware if you are using the default constructor and still require TCP, you should add an additional argument:

```ruby
# Now defaults to UDP instead of TCP
logger = LogStashLogger.new('localhost', 5228)
# Explicitly specify TCP instead of UDP
logger = LogStashLogger.new('localhost', 5228, :tcp)
```
