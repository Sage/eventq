module EventQ
  class EventRaisedQueue < Queue
    def initialize
      @name = 'eventq.eventraised'
    end
  end
end
