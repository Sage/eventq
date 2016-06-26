module EventQ
  class EventRaisedExchange < Exchange
    def initialize
      @name = 'eventq.eventraised.ex'
    end
  end
end
