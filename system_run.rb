# encoding: utf-8
require 'timeout'
require 'tempfile'

module System
  def self.run(cmd, *args, timeout: nil, env: {}, capture: :default, file: nil, cwd: '.', on_timeout: nil)
    cmd = cmd.dup << ' ' << args.join(' ')
    env = env.dup.map { |k, v| [k.to_s, v.to_s] }.to_h

    raise ArgumentError, "file(s) must be instance of File or Tempfile" unless file.nil? || file.all? { |f| f.is_a?(File) || f.is_a?(Tempfile) }
    out, err = case capture
               when :default then
                 raise ArgumentError, "invalid file redirects for default capture, expected array of two" unless file.nil? || file.is_a?(Array) && file.size == 2
                 file ? [file.first, file.last] : [Tempfile.new('sysrun-out'), Tempfile.new('sysrun-err')]
               when :out then [file || Tempfile.new('sysrun-out'), '/dev/null']
               when :err then ['/dev/null', file || Tempfile.new('sysrun-err')]
               when :both then [file || Tempfile.new('sysrun-outerr')] * 2
               else raise ArgumentError, "unknown capture: #{capture}"
               end

    pid = spawn env, cmd, out: out, err: err, chdir: cwd
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
      Timeout::timeout(timeout) do
        Process.wait pid
      end
    rescue Timeout::Error
      if on_timeout then
        on_timeout.call pid
      else
        Process.kill 9, pid
      end
      Process.wait pid
    end

    $?
  end

  private_class_method :wait_or_kill
end

if __FILE__ == $0 then
  date = %q(ruby -e "t = Time.now; STDOUT.puts t; STDERR.puts t")

  # capture stdout and stderr separately.
  status, stdout, stderr = System.run date
  p [status, stdout, stderr]

  # capture only stdout, discard stderr.
  status, stdout = System.run date, capture: :out
  p [status, stdout]

  # capture stderr and discard stdout.
  status, stderr = System.run date, capture: :err
  p [status, stderr]

  # capture both stdout and stderr.
  status, all = System.run date, capture: :both
  p [status, all]

  # capture stderr. kill process after 2 seconds.
  loop_time = %q(ruby -e "loop { STDERR.puts Time.now.to_i; sleep 2 }")
  status, stderr = System.run loop_time, capture: :err, timeout: 2
  p [status, stderr]

  # set timeout to 2 seconds and provide an action for when timeout occurs. default
  # action is to send signal 9. this will be overridden!
  status, _, _ = System.run %q(ruby -e "sleep 10"), timeout: 2, on_timeout: ->(pid) do
    puts 'oh no, request timed out'
    Process.kill 9, pid
  end
  p status

  # set environment variables.
  env = %q(ruby -e "puts ENV['HELLO']")
  status, stdout = System.run env, env: {'HELLO' => 'WORLD'}, capture: :out
  p [status, stdout]

  # switch to a different directory before executing the command.
  dir = %q(ruby -e "puts Dir.pwd")
  status, stdout = System.run dir, cwd: Dir.tmpdir, capture: :out
  p [status, stdout]

  # write to a file instead of loading output into a string.
  out = File.open 'test_out.txt', 'w+'
  err = File.open 'test_err.txt', 'w+'

  hello = %q(ruby -e "STDERR.puts 'hello'; STDOUT.puts 'world'")
  status = System.run hello, file: [out, err]
  p [status, out.read, err.read]

  [out, err].each { |f| f.close; File.unlink f.path }
end
