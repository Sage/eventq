# frozen_string_literal: true

require 'concurrent'

module EventQ
  # Class used to represent the main worker status and the collection of forked worker processes.
  # The main worker process will not have access to a forks collection of processes and threads.
  # This is due to forks getting a copy of the process memory space and there is no such thing as shared resources
  # between child processes and the parent process.  Without implementing a need using inter process communication with
  # IO::Pipe, only the PID is of any use for the parent process.
  # To summarize, if using forks, the parent process will only have a collection of PIDS and not any threads
  # associated with those PIDS.
  class WorkerStatus

    # List of WorkerProcess
    attr_reader :processes

    def initialize
      @processes = Concurrent::Array.new
    end

    # Retrieve a simple list of all PIDS.
    def pids
      list = []
      @processes.each do |p|
        list.push(p.pid)
      end
      list
    end

    # Retrieve a simple list of all threads.
    # Important Note:  The list of threads is only relevant to the current process.
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

  # Class that is used to represent a process and its associated threads.
  class WorkerProcess
    attr_accessor :pid
    attr_reader :threads
    def initialize(pid)
      self.pid = pid
      @threads = Concurrent::Array.new
    end
  end

  class WorkerThread
    # This could be a string or a Thread object.
    # When spawning forked workers, threads cannot be marshalled back to another process.
    attr_reader :thread

    def initialize(thread)
      @thread = thread
    end
  end
end
