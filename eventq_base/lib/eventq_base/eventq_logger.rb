require 'logger'

module EventQ

  def self.logger
    return @@logger
  end

  def self.set_logger(logger)
    @@logger = logger
  end

  EventQ.set_logger(Logger.new(STDOUT))

end