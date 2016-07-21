require 'logger'

module EventQ

  def self.logger
    return @@logger
  end

  def self.set_logger(logger)
    @@logger = logger
  end

  def self.log(type, message)
    case type
      when :info
        logger.info(message)
      when :debug
        logger.debug(message)
      when :error
        logger.error(message)
    end
  rescue
    #do nothing
  end

  EventQ.set_logger(Logger.new(STDOUT))

end