# frozen_string_literal: true

require 'concurrent'

module EventQ
  class WorkerStatus
    attr_reader :processes
    def initialize
      @processes = Concurrent::Array.new
    end

    def threads
      list = []
      @processes.each do |p|
        p.threads.each do |t|
          list.push(t)
        end
      end

      list
    end
  end

  class WorkerProcess
    attr_accessor :pid
    attr_reader :threads
    def initialize(pid)
      self.pid = pid
      @threads = Concurrent::Array.new
    end
  end

  class WorkerThread
    attr_reader :thread

    def initialize(thread)
      @thread = thread
    end
  end
end
