module Fluent
  class Fluent::ZmqPubOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('zmq_pub', self)

    config_param :pubkey, :string
    config_param :bindaddr, :string, :default => 'tcp://*:5556'

    def initialize
      super
      require 'ffi-rzmq'
      @mutex = Mutex.new
    end

    def configure(conf)
      super
    end
    
    def start
      super
      @context = ZMQ::Context.new(1)
      @publisher = @context.socket(ZMQ::PUB)
      @publisher.bind(@bindaddr)
    end

    def format(tag, time, record)
      [tag,time,record].to_msgpack
    end

    def write(chunk)
      records = { }
      #  to_msgpack in format, unpack in write, then to_msgpack again... better way?
      chunk.msgpack_each{ |record|
        pubkey_replaced = @pubkey.gsub(/\${(.*?)}/){ |s|
          case $1
          when 'tag'
            record[0]
          else
            record[2][$1]
          end
        }
        records[pubkey_replaced] ||= []
        records[pubkey_replaced] << record

      }
      records.each{ |k,v|
        @publisher.sendmsg(ZMQ::Message.create(k + " " + v.to_msgpack),ZMQ::DONTWAIT)
      }
    end
 
    def shutdown
      super
      @publisher.close
      @context.terminate
    end

  end

end
