module EventQ
  def self.namespace
    @namespace
  end

  def self.namespace=(value)
    @namespace = value
  end

  def self.create_event_type(event_type, namespace = nil)
    # if namespace is empty string, suppress EventQ.namespace
    return event_type if namespace == '' || (EventQ.namespace.nil? && namespace.nil?)

    # if namespace is not nil prefer it to EventQ.namespace
    return "#{namespace}-#{event_type}" if namespace

    "#{EventQ.namespace}-#{event_type}"
  end

  def self.create_queue_name(queue, namespace = nil)
    # if namespace is empty string, suppress EventQ.namespace
    return queue.name if namespace == '' || (EventQ.namespace.nil? && namespace.nil?)

    delimiter = queue.namespace_delimiter || '-'

    # if namespace is not nil prefer it to EventQ.namespace
    return "#{namespace}#{delimiter}#{queue.name}" if namespace

    "#{EventQ.namespace}#{delimiter}#{queue.name}"
  end
end
