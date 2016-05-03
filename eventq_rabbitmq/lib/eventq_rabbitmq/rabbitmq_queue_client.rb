class RabbitMqQueueClient

  attr_accessor :channel

  def initialize

    @endpoint = 'localhost'
    if ENV['MQ_ENDPOINT'] != nil
      @endpoint = ENV['MQ_ENDPOINT']
    end

    @port = 5672
    if ENV['MQ_PORT'] != nil
      @port = Integer(ENV['MQ_PORT'])
    end

    @user = 'guest'
    if ENV['MQ_USER'] != nil
      @user = ENV['MQ_USER']
    end

    @password = 'guest'
    if ENV['MQ_PASSWORD'] != nil
      @password = ENV['MQ_PASSWORD']
    end

    @ssl = false
    if ENV['MQ_SSL'] != nil
      @ssl = ENV['MQ_SSL']
    end

    #@conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
    #@conn.start
    #@channel = conn.create_channel
  end

  def get_channel
    conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
    conn.start
    return conn.create_channel
  end

end