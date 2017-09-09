class EvalError < StandardError
  def initialize(msg); super; end
end

class SafeRuby
  SELF_READ, SELF_WRITE = IO.pipe

  def self.eval(code)
    reader, writer = IO.pipe
    pid = fork {      
      reader.close
      
      result = begin
                SafeRuby::Sandbox.init_sandbox
                SafeRuby::Sandbox.run! code
              rescue => e
                e
              end
      

      writer.write Marshal.dump(result)
      writer.write("\n")
      writer.close
    }

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

    reader.each_line do |line|
      data = Marshal.load(line)
      raise data if data.is_a?(StandardError)
      return data
    end
  end

  def self.check(code, expected)
    eval(code) == eval(expected)
  end
end
