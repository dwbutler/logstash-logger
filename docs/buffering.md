# Buffering and Automatic Retries

For devices that establish a connection to a remote service, log messages are buffered internally
and flushed in a background thread. If there is a connection problem, the
messages are held in the buffer and automatically resent until it is successful.
Outputs that support batch writing (Redis and Kafka) will write log messages in bulk from the
buffer. This functionality is implemented using a fork of
[Stud::Buffer](https://github.com/jordansissel/ruby-stud/blob/master/lib/stud/buffer.rb).

## Configuration Options

You can configure buffering behavior by passing the following options to LogStashLogger:

* `:buffer_max_items` - Max number of items to buffer before flushing. Defaults to 50.
* `:buffer_max_interval` - Max number of seconds to wait between flushes. Defaults to 5.
* `:drop_messages_on_flush_error` - Drop messages when there is a flush error. Defaults to false.
* `:drop_messages_on_full_buffer` - Drop messages when the buffer is full. Defaults to true.
* `:sync` - Flush buffer every time a message is received (blocking). Defaults to false.
* `:buffer_flush_at_exit` - Flush messages when exiting the program. Defaults to true.
* `:buffer_logger` - Logger to write buffer debug/error messages to. Defaults to none.

You can turn buffering off by setting `sync = true`.

## Caveats

Please be aware of the following caveats to this behavior:

* It's possible for duplicate log messages to be sent when retrying. For outputs like Redis and
  Kafka that write in batches, the whole batch could get re-sent. If this is a problem, you
  can add a UUID field to each event to uniquely identify it. You can either do this
  in a `customize_event` block, or by using logstash's
  [UUID filter](https://www.elastic.co/guide/en/logstash/current/plugins-filters-uuid.html).
* It's still possible to lose log messages. Ruby won't detect a TCP/UDP connection problem
  immediately. In my testing, it took Ruby about 4 seconds to notice the receiving end was down
  and start raising exceptions. Since logstash listeners over TCP/UDP do not acknowledge received
  messages, it's not possible to know which log messages to re-send.
* When `sync` is turned off, Ruby may buffer data internally before writing to
  the IO device. This is why you may not see messages written immediately to a
  UDP or TCP socket, even though LogStashLogger's buffer is periodically flushed.

## Full Buffer

By default, messages are discarded when the buffer gets full. This can happen
if the output source is down for too long or log messages are being received
too quickly. If your application suddenly terminates (for example, by SIGKILL or a power outage),
the whole buffer will be lost.

You can make message loss less likely by increasing `buffer_max_items`
(so that more events can be held in the buffer), and decreasing `buffer_max_interval` (to wait
less time between flushes). This will increase memory pressure on your application as log messages
accumulate in the buffer, so make sure you have allocated enough memory to your process.

If you don't want to lose messages when the buffer gets full, you can set
`drop_messages_on_full_buffer = false`. Note that if the buffer gets full, any
incoming log message will block, which could be undesirable.

## Sync Mode

All logger outputs support a `sync` setting. This is analogous to the "sync mode" setting on Ruby IO
objects. When set to `true`, output is immediately flushed and is not buffered internally. Normally,
for devices that connect to a remote service, buffering is a good thing because
it improves performance and reduces the likelihood of errors affecting the program. For these devices,
`sync` defaults to `false`, and it is recommended to leave the default value.
You may want to turn sync mode on for testing, for example if you want to see
log messages immediately after they are written.

It is recommended to turn sync mode on for file and Unix socket outputs. This
ensures that log messages from different threads or processes are written correctly on separate lines.

See [#44](https://github.com/dwbutler/logstash-logger/issues/44) for more details.
