class EvalError < StandardError
  def initialize(msg); super; end
end

class SafeRuby
  SELF_READ, SELF_WRITE = IO.pipe

  def self.run(code)
    reader, writer = IO.pipe

    ActiveRecord::Base.connection.disconnect!
    pid = Process.fork {
      ActiveRecord::Base.connection.reconnect!
      reader.close
      
      result = begin
                SafeRuby::Sandbox.init_sandbox
                SafeRuby::Sandbox.run! code
              rescue => e
                e
              end
      
      writer.write Marshal.dump(result)
      writer.flush
      writer.close
    }

    ActiveRecord::Base.connection.reconnect!

    writer.close
    while true
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        break
      end

      rw, _, _ = IO.select([reader, SELF_READ], [], [], 1)
      next if rw.blank? || rw.include?(SELF_READ)
      break
    end

    line = ''

    until reader.eof?
      line += reader.read_nonblock(16000)
    end

    puts line.length

    data =  nil 
    Object.class_eval do
      data = begin
              Marshal.load(line)
             rescue ArgumentError => e 
               if e.message =~ /undefined class\/module (.*)$/
                 $1.constantize  
               end
               Marshal.load(line)
             end
    end

    raise data if data.is_a?(StandardError)
    return data
  end

  def self.check(code, expected)
    eval(code) == eval(expected)
  end
end
