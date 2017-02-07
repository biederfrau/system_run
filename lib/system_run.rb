# encoding: utf-8
require 'timeout'
require 'tempfile'

module System
  def self.run(cmd, *args, timeout: nil, env: {}, capture: :default, file: nil, cwd: '.', on_timeout: nil, **kwargs)
    cmd = cmd.dup << ' ' << args.join(' ')
    env = env.dup.map { |k, v| [k.to_s, v.to_s] }.to_h

    unless file.nil? || file.all? { |f| f.is_a?(File) || f.is_a?(Tempfile) }
      raise ArgumentError, "file(s) must be instance of File or Tempfile"
    end

    unless capture != :default || file.nil? || file.is_a?(Array) && file.size == 2
      raise ArgumentError, "invalid file redirects for default capture, expected array of two"
    end

    out, err = case capture
               when :default then file ? [file.first, file.last] : [Tempfile.new('sysrun-out'), Tempfile.new('sysrun-err')]
               when :out then [file || Tempfile.new('sysrun-out'), '/dev/null']
               when :err then ['/dev/null', file || Tempfile.new('sysrun-err')]
               when :both then [file || Tempfile.new('sysrun-outerr')] * 2
               else raise ArgumentError, "unknown capture: #{capture}"
               end

    pid = spawn env, cmd, out: out, err: err, chdir: cwd, **kwargs
    status = wait_or_kill pid, timeout, on_timeout
    [out, err].each { |f| f.rewind if f.respond_to? :rewind }

    file ? status : case capture
                    when :default then [status, out.read, err.read]
                    when :out, :both then [status, out.read]
                    when :err then [status, err.read]
                    end
  ensure
    [out, err].each { |f| f.unlink if f.is_a?(Tempfile) && f.path&.include?('sysrun') }
  end

  def self.wait_or_kill(pid, timeout=nil, on_timeout=nil)
    begin
      Timeout::timeout(timeout) { Process.wait pid }
    rescue Timeout::Error
      on_timeout ? on_timeout.call(pid) : Process.kill(9, pid)
      Process.wait pid
    end

    $?
  end

  private_class_method :wait_or_kill
end
