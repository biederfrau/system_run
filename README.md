# system_run
Tiny wrapper for running commands. Inspired by systemu.

System.run is a wrapper for making subprocess-spawning more ergonomic. It uses
Ruby's `Kernel.spawn` internally and supports setting a timeout, environment
variables, a working directory, files for redirecting, a custom action for when
a timeout occurs and other options that are forwarded to `spawn` as-is.

## Examples

```ruby
# capture both stderr and stdout, but separately.
program = %q{ruby -e "STDOUT.print 'hello'; STDERR.print 'world'"}
System.run program
# => [#<Process::Status: pid 20407 exit 0>, "hello", "world"]

# only capture stdout.
System.run program, capture: :out
# => [#<Process::Status: pid 20421 exit 0>, "hello"]

# only capture stderr.
System.run program, capture: :err
# => [#<Process::Status: pid 20458 exit 0>, "world"]

# capture both stdout and stderr into the same string.
# stdout is buffered, stderr is not!
System.run program, capture: :both
# => [#<Process::Status: pid 20464 exit 0>, "worldhello"]

# kill (send signal 9) process after the specified time.
program = %q{ruby -e "STDERR.print 'this can only end badly'; loop { sleep 1 }"} #"
System.run program, timeout: 2, capture: :both
# ...
# => [#<Process::Status: pid 20507 SIGKILL (signal 9)>, "this can only end badly"]

# override default action with sending SIGTERM and setting a control variable.
state = :everything_is_great
System.run program, timeout: 2, capture: :both, on_timeout: ->(pid) do
  state = :oh_no
  Process.kill 15, pid
end
# ...
# => [#<Process::Status: pid 20519 SIGTERM (signal 15)>, "this can only end badly"]

# set some environment variable.
program = %{ruby -e "STDERR.print ENV['hello']; STDOUT.print Dir.pwd"}
System.run program, capture: :err, env: {'hello' => 2}
# => [#<Process::Status: pid 20540 exit 0>, "2"]

# set working dir.
System.run program, capture: :out, cwd: Dir.tmpdir
# => [#<Process::Status: pid 20545 exit 0>, "/tmp"]

# redirect to file (File or Tempfile or descendants)
program = %q{ruby -e "STDOUT.print 'hello'; STDERR.print 'world'"}
out = Tempfile.new 'out'
err = Tempfile.new 'err'
System.run program, file: [out, err]
# => #<Process::Status: pid 20553 exit 0>
out.read
# => "hello"
err.read
# => "world"

# everything works the same!
out = Tempfile.new 'out'
System.run program, file: out, capture: :both
# => #<Process::Status: pid 20591 exit 0>
[5] pry(main)> out.read
# => "worldhello"

# you can specify some file to be used as stdin. this option is passed
# directly to Kernel.spawn.
input = Tempfile.new.tap { |f| f.write('system_run'); f.rewind }
echo = %q{ruby -e "print STDIN.gets"}
System.run echo, in: input, capture: :out
# => [#<Process::Status: pid 20605 exit 0>, "system_run"]
```
