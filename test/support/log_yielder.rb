# Make it easy to assert on a string line generated through the standard lib
# progname & block syntax. This class will automatically yield the block and
# concat it the mock receives a single line. This also ensures the block
# is always executed, making sure it's free of errors
class LogYielder
  include Concord.new(:log)

  def info(msg)
    if msg && block_given?
      log.info "#{msg} #{yield}"
    else
      log.info msg
    end
  end

  def error(msg)
    if msg && block_given?
      log.error "#{msg} #{yield}"
    else
      log.error msg
    end
  end

  def debug(msg)
    if msg && block_given?
      log.debug "#{msg} #{yield}"
    else
      log.debug msg
    end
  end
end

