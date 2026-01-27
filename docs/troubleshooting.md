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

A known drawback of using TCP or UDP is the 65535 byte limit on total message size. To workaround
this issue, you will have to truncate the message by setting the max message size:

```ruby
LogStashLogger.configure do |config|
  config.max_message_size = 2000
end
```

This will truncate only the `message` field of the LogStash Event. So make sure
you set the max message size significantly less than 65535 bytes to make room
for other fields.

# Breaking changes

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
