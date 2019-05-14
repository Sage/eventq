module EventQ
  def self.namespace
    @namespace
  end

  def self.namespace=(value)
    @namespace = value
  end

  def self.create_event_type(event_type)
    if EventQ.namespace == nil
      return event_type
    end
    return "#{EventQ.namespace}-#{event_type}"
  end

  def self.create_queue_name(queue)
    return queue.name if EventQ.namespace == nil

    delimiter = queue.namespace_delimiter || '-'
    return "#{EventQ.namespace}#{delimiter}#{queue.name}"
  end
end
