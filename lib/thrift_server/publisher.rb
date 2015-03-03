module ThriftServer
  class Publisher
    include Enumerable

    extend Forwardable

    def_delegators :listeners, :each

    attr_reader :listeners

    def initialize
      @listeners = [ ]
    end

    def subscribe(object)
      listeners << object
    end

    def publish(event, *args)
      listeners.each do |listener|
        listener.send(event, *args) if listener.respond_to? event
      end
    end
  end
end
