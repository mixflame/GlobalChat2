class Qt::Thread < ::Thread
    class ThreadsTimer < Qt::Object
        protected
        def timerEvent(ev)
        end

        def initialize
            super
            startTimer 0
        end
    end

    @threads_timer = nil

    def Thread.enable_ruby_threads
        # Start timer if only it hasn't been started yet
        return if @threads_timer

        @threads_timer = ThreadsTimer.new
    end
    private_class_method(:enable_ruby_threads)

    def Thread.disable_ruby_threads
        # Stop timer only if we have main thread and just one custom
        # which will be stopped right after this call
        return unless Thread.list.count == 2

        @threads_timer.dispose
        @threads_timer = nil
    end
    private_class_method(:disable_ruby_threads)

    def self.decorate_block(*args, &block)
        enable_ruby_threads
        proc{ block.call *args; disable_ruby_threads }
    end
    private_class_method(:decorate_block)

    def self.new(*args, &block)
        super *args, &decorate_block(*args, &block)
    end

    def self.start(*args, &block)
        super *args, &decorate_block(*args, &block)
    end

    def self.fork(*args, &block)
        super *args, &decorate_block(*args, &block)
    end
end