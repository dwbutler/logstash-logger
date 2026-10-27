# Forked from https://github.com/jordansissel/ruby-stud/blob/master/lib/stud/buffer.rb

module LogStashLogger

  # @author {Alex Dean}[http://github.com/alexdean]
  #
  # Implements a generic framework for accepting events which are later flushed
  # in batches. Flushing occurs whenever +:max_items+ or +:max_interval+ (seconds)
  # has been reached.
  #
  # Including class must implement +flush+, which will be called with all
  # accumulated items either when the output buffer fills (+:max_items+) or
  # when a fixed amount of time (+:max_interval+) passes.
  #
  # == batch_receive and flush
  # General receive/flush can be implemented in one of two ways.
  #
  # === batch_receive(event) / flush(events)
  # +flush+ will receive an array of events which were passed to +buffer_receive+.
  #
  #   batch_receive('one')
  #   batch_receive('two')
  #
  # will cause a flush invocation like
  #
  #   flush(['one', 'two'])
  #
  # === batch_receive(event, group) / flush(events, group)
  # flush() will receive an array of events, plus a grouping key.
  #
  #   batch_receive('one',   :server => 'a')
  #   batch_receive('two',   :server => 'b')
  #   batch_receive('three', :server => 'a')
  #   batch_receive('four',  :server => 'b')
  #
  # will result in the following flush calls
  #
  #   flush(['one', 'three'], {:server => 'a'})
  #   flush(['two', 'four'],  {:server => 'b'})
  #
  # Grouping keys can be anything which are valid Hash keys. (They don't have to
  # be hashes themselves.) Strings or Fixnums work fine. Use anything which you'd
  # like to receive in your +flush+ method to help enable different handling for
  # various groups of events.
  #
  # == on_flush_error
  # Including class may implement +on_flush_error+, which will be called with an
  # Exception instance whenever buffer_flush encounters an error.
  #
  # * +buffer_flush+ will automatically re-try failed flushes, so +on_flush_error+
  #   should not try to implement retry behavior.
  # * Exceptions occurring within +on_flush_error+ are not handled by
  #   +buffer_flush+.
  #
  # == on_full_buffer_receive
  # Including class may implement +on_full_buffer_receive+, which will be called
  # whenever +buffer_receive+ is called while the buffer is full.
  #
  # +on_full_buffer_receive+ will receive a Hash like <code>{:pending => 30,
  # :outgoing => 20}</code> which describes the internal state of the module at
  # the moment.
  #
  # == final flush
  # Including class should call <code>buffer_flush(:final => true)</code>
  # during a teardown/shutdown routine (after the last call to buffer_receive)
  # to ensure that all accumulated messages are flushed.
  module Buffer
    # Buffers to flush when the process exits. Weak keys, so a closed or
    # unreachable device can be garbage-collected; closed devices are marked
    # false, since ObjectSpace::WeakMap has no delete.
    AT_EXIT_REGISTRY = ObjectSpace::WeakMap.new

    at_exit do
      AT_EXIT_REGISTRY.each do |buffer, live|
        next unless live
        begin
          buffer.buffer_flush(final: true)
        rescue StandardError
        end
      end
    end

    # Initialize the buffer.
    #
    # Call directly from your constructor if you wish to set some non-default
    # options. Otherwise buffer_initialize will be called automatically during the
    # first buffer_receive call.
    #
    # Options:
    # * :max_items, Max number of items to buffer before flushing. Default 50.
    # * :max_interval, Max number of seconds to wait between flushes. Default 5.
    # * :logger, A logger to write log messages to. No default. Optional.
    # * :autoflush, Whether to immediately flush all inbound messages. Default true.
    # * :drop_messages_on_flush_error, Whether to drop messages when there is a flush error. Default false.
    # * :drop_messages_on_full_buffer, Whether to drop messages when the buffer is full. Default false.
    #
    # @param [Hash] options
    def buffer_initialize(options={})
      if ! self.class.method_defined?(:flush)
        raise ArgumentError, "Any class including Stud::Buffer must define a flush() method."
      end

      @buffer_config = {
        :max_items => options[:max_items] || 50,
        :max_interval => options[:max_interval] || 5,
        :logger => options[:logger] || nil,
        :autoflush => options.fetch(:autoflush, true),
        :has_on_flush_error => self.class.method_defined?(:on_flush_error),
        :has_on_full_buffer_receive => self.class.method_defined?(:on_full_buffer_receive),
        :drop_messages_on_flush_error => options.fetch(:drop_messages_on_flush_error, false),
        :drop_messages_on_full_buffer => options.fetch(:drop_messages_on_full_buffer, false),
        :flush_at_exit => options.fetch(:flush_at_exit, false),
        :final_flush_timeout => options.fetch(:final_flush_timeout, nil)
      }

      @buffer_shutdown = false
      AT_EXIT_REGISTRY[self] = true if @buffer_config[:flush_at_exit]

      reset_buffer
    end

    def reset_buffer
      reset_flush_timer_thread
      # The new state starts with no count, so report the old one first
      report_dropped_records if @buffer_state

      @buffer_state = {
        # items accepted from including class
        :pending_items => {},
        :pending_count => 0,

        # guard access to pending_items & pending_count
        :pending_mutex => pending_mutex,

        # items which are currently being flushed
        :outgoing_items => {},
        :outgoing_count => 0,

        # ensure only 1 flush is operating at once
        :flush_mutex =>    flush_mutex,

        # data for timed flushes
        :last_flush =>     Time.now,
        :last_flush_error => nil,
        :timer =>          flush_timer_thread,

        # records dropped because the buffer was full, reported once per episode
        :dropped_count =>  0,
        :full_reported =>  false
      }

      # events we've accumulated
      buffer_clear_pending
    end

    # Determine if +:max_items+ has been reached.
    #
    # buffer_receive calls will block while <code>buffer_full? == true</code>.
    #
    # @return [bool] Is the buffer full?
    def buffer_full?
      @buffer_state[:pending_count] + @buffer_state[:outgoing_count] >= @buffer_config[:max_items]
    end

    # Save an event for later delivery
    #
    # Events are grouped by the (optional) group parameter you provide.
    # Groups of events, plus the group name, are later passed to +flush+.
    #
    # This call will block if +:max_items+ has been reached.
    #
    # @see Stud::Buffer The overview has more information on grouping and flushing.
    #
    # @param event An item to buffer for flushing later.
    # @param group Optional grouping key. All events with the same key will be
    #              passed to +flush+ together, along with the grouping key itself.
    def buffer_receive(event, group=nil)
      buffer_initialize if ! @buffer_state
      return if buffer_shutdown?

      make_room if buffer_full?

      while buffer_full? do
        dropping = @buffer_config[:drop_messages_on_full_buffer]
        report_full_buffer(dropping)
        # Drop this record, not the ones already queued
        return if dropping
        sleep 0.1
        return if buffer_shutdown?
        make_room
      end
      report_dropped_records

      @buffer_state[:pending_mutex].synchronize do
        # Checked under the lock buffer_shutdown clears the buffer with, so a
        # record is never added after the shutdown
        return if buffer_shutdown?
        @buffer_state[:pending_items][group] << event
        @buffer_state[:pending_count] += 1
      end

      if @buffer_config[:autoflush]
        buffer_flush(force: true)
      elsif buffer_full?
        # The record that fills the buffer flushes it
        make_room
      end
    end

    # Put items back into the pending queue for the next flush, without
    # applying the full-buffer policy. Safe to call from inside a flush.
    def buffer_requeue(items, group=nil)
      return if items.empty? || buffer_shutdown?
      @buffer_state[:pending_mutex].synchronize do
        # Checked again under the lock buffer_shutdown clears the buffer with
        return if buffer_shutdown?
        @buffer_state[:pending_items][group].concat(items)
        @buffer_state[:pending_count] += items.size
      end
      # Belongs to the running flush, not to whichever state is current: a
      # reset during the flush must not carry it into the next one
      @flush_requeued = true
    end

    # Try to flush events.
    #
    # Returns immediately if flushing is not necessary/possible at the moment:
    # * :max_items have not been accumulated
    # * :max_interval seconds have not elapased since the last flush
    # * another flush is in progress
    #
    # <code>buffer_flush(:force => true)</code> will cause a flush to occur even
    # if +:max_items+ or +:max_interval+ have not been reached. A forced flush
    # will still return immediately (without flushing) if another flush is
    # currently in progress.
    #
    # <code>buffer_flush(:final => true)</code> is identical to <code>buffer_flush(:force => true)</code>,
    # except that if another flush is already in progress, <code>buffer_flush(:final => true)</code>
    # will block/wait for the other flush to finish before proceeding.
    #
    # @param [Hash] options Optional. May be <code>{:force => true}</code> or <code>{:final => true}</code>.
    # @return [Fixnum] The number of items successfully passed to +flush+.
    def buffer_flush(options={})
      return 0 if buffer_shutdown?
      force = options[:force] || options[:final]
      final = options[:final]
      # Work on the state this flush started with. Connectable#reset or
      # drop_messages_on_flush_error can replace @buffer_state while a flush is
      # in progress, and this flush's bookkeeping must not leak into the new one.
      state = @buffer_state

      # final flush will wait for lock, so we are sure to flush out all buffered events
      if options[:final]
        return 0 unless lock_for_final_flush(state)
        # A reset while this flush waited replaced the state; flush what the
        # buffer holds now. The lock is the same object in the new state.
        state = @buffer_state
      elsif ! state[:flush_mutex].try_lock # failed to get lock, another flush already in progress
        return 0
      end

      items_flushed = 0
      @flush_requeued = false

      begin
        time_since_last_flush = (Time.now - state[:last_flush])

        return 0 if state[:pending_count] == 0
        return 0 if (!force) &&
           (state[:pending_count] < @buffer_config[:max_items]) &&
           (time_since_last_flush < @buffer_config[:max_interval])

        state[:pending_mutex].synchronize do
          state[:outgoing_items] = state[:pending_items]
          state[:outgoing_count] = state[:pending_count]
          buffer_clear_pending(state)
        end

        @buffer_config[:logger].debug do
          debug_output = {
            :outgoing_count => state[:outgoing_count],
            :time_since_last_flush => time_since_last_flush,
            :outgoing_events => state[:outgoing_items],
            :batch_timeout => @buffer_config[:max_interval],
            :force => force,
            :final => final
          }
          "Flushing output: #{debug_output}"
        end if @buffer_config[:logger]

        state[:outgoing_items].each do |group, events|
          begin
            if group.nil?
              flush(events,final)
            else
              flush(events, group, final)
            end

            state[:outgoing_items].delete(group)
            events_size = events.size
            state[:outgoing_count] -= events_size
            items_flushed += events_size
            state[:last_flush] = Time.now
            # Records the output put back to retry count as a failed flush,
            # so writers wait buffer_max_interval before trying again.
            state[:last_flush_error] = @flush_requeued ? Time.now : nil

          rescue => e
            state[:last_flush_error] = Time.now

            @buffer_config[:logger].warn do
              warn_output = {
                :outgoing_count => state[:outgoing_count],
                :exception => e.class.name,
                :backtrace => e.backtrace
              }
              "Failed to flush outgoing items: #{warn_output}"
            end if @buffer_config[:logger]

            if @buffer_config[:has_on_flush_error]
              on_flush_error e
            end

            if @buffer_config[:drop_messages_on_flush_error]
              reset_buffer
            else
              cancel_flush(state)
            end

          end
        end

      ensure
        state[:flush_mutex].unlock
      end

      # Report the records dropped while the buffer was full as soon as a
      # flush makes room, not only on the next log call
      report_dropped_records if items_flushed > 0 && !buffer_full?
      return items_flushed
    end

    # Stops the buffer for good: no timer, no flushes, and records written
    # afterwards are dropped. Called once from Connectable#close, after the
    # final flush. Never kills the current thread, so it also completes when
    # called from inside a timed flush.
    def buffer_shutdown
      @buffer_shutdown = true
      AT_EXIT_REGISTRY[self] = false if AT_EXIT_REGISTRY.key?(self)
      timer, @flush_timer_thread = @flush_timer_thread, nil
      timer.kill if timer && timer != Thread.current
      # Nothing can flush these any more, including records the final flush
      # could not send or still holds
      if @buffer_state
        @buffer_state[:pending_mutex].synchronize do
          buffer_clear_pending
          buffer_clear_outgoing
        end
      end
    end

    def buffer_shutdown?
      @buffer_shutdown == true
    end

    private

    # A final flush waits for a flush that is already running, but for no
    # longer than final_flush_timeout seconds (nil waits forever), so a flush
    # stuck on an unresponsive output cannot keep the process from exiting.
    def lock_for_final_flush(state)
      timeout = @buffer_config[:final_flush_timeout]
      return state[:flush_mutex].lock if timeout.nil?
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      return true if state[:flush_mutex].try_lock
      loop do
        sleep 0.01
        # Checked before trying the lock, so a lock freed only after the
        # deadline does not start a flush that could block again
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          unsent = [state, @buffer_state].uniq(&:object_id).sum { |s| s[:pending_count] + s[:outgoing_count] }
          on_final_flush_timeout(unsent) if respond_to?(:on_final_flush_timeout)
          return false
        end
        return true if state[:flush_mutex].try_lock
      end
    end

    def pending_mutex
      @pending_mutex ||= Mutex.new
    end

    def flush_mutex
      @flush_mutex ||= Mutex.new
    end

    def flush_timer_thread
      return nil if buffer_shutdown?
      @flush_timer_thread ||=
        Thread.new do
          loop do
            # Also checked before sleeping, for a close made from inside the
            # previous timed flush
            break if buffer_shutdown?
            sleep(@buffer_config[:max_interval])
            break if buffer_shutdown?
            begin
              buffer_flush(:force => true)
            rescue
            end
          end
        end
    end

    # Never kills the timer from inside itself: called on the timer thread,
    # this keeps the running timer, and reset_buffer reuses it.
    def reset_flush_timer_thread
      return if @flush_timer_thread.nil? || @flush_timer_thread == Thread.current
      @flush_timer_thread.kill
      @flush_timer_thread = nil
    end

    # A writer that finds the buffer full flushes it itself, unless a flush is
    # already running or the last one failed recently (so a down collector does
    # not turn every log call into a connection attempt).
    def make_room
      last_error = @buffer_state[:last_flush_error]
      return if last_error && (Time.now - last_error) < @buffer_config[:max_interval]
      buffer_flush(force: true)
    end

    # Counts a dropped record in the same step that opens the episode, so a
    # writer that finds room meanwhile cannot report the episode without it.
    def report_full_buffer(dropping = false)
      opened = @buffer_state[:pending_mutex].synchronize do
        @buffer_state[:dropped_count] += 1 if dropping
        first = !@buffer_state[:full_reported]
        @buffer_state[:full_reported] = true
        first
      end
      return unless opened
      on_full_buffer_receive(
        :pending => @buffer_state[:pending_count],
        :outgoing => @buffer_state[:outgoing_count]
      ) if @buffer_config[:has_on_full_buffer_receive]
    end

    def report_dropped_records
      return unless @buffer_state[:full_reported]
      dropped = @buffer_state[:pending_mutex].synchronize do
        count = @buffer_state[:dropped_count]
        @buffer_state[:dropped_count] = 0
        @buffer_state[:full_reported] = false
        count
      end
      on_buffer_drops(dropped) if dropped > 0 && respond_to?(:on_buffer_drops, true)
    end

    def buffer_clear_pending(state = @buffer_state)
      state[:pending_items] = Hash.new { |h, k| h[k] = [] }
      state[:pending_count] = 0
    end

    def buffer_clear_outgoing(state = @buffer_state)
      state[:outgoing_items] = Hash.new { |h, k| h[k] = [] }
      state[:outgoing_count] = 0
    end

    def cancel_flush(state = @buffer_state)
      # After shutdown nothing could send them again
      return buffer_clear_outgoing(state) if buffer_shutdown?
      state[:pending_mutex].synchronize do
        state[:outgoing_items].each do |group, items|
          state[:pending_items][group].concat items
        end
        state[:pending_count] += state[:outgoing_count]
      end
      buffer_clear_outgoing(state)
    end
  end
end
