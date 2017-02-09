# system_run
Tiny wrapper for running commands. Inspired by systemu.

System.run is a wrapper for making subprocess-spawning more ergonomic. It uses
Ruby's `Kernel.spawn` internally and supports setting a timeout, environment
variables, a working directory, files for redirecting, a custom action for when
a timeout occurs and other options that are forwarded to `spawn` as-is.

## Examples

System.run will by default capture stderr and stdout separately and return
them as strings along with the process exit state.

```ruby
# capture both stderr and stdout, but separately.
program = %q{ruby -e "STDOUT.print 'hello'; STDERR.print 'world'"}
System.run program
# => [#<Process::Status: pid 20407 exit 0>, "hello", "world"]
```

You can also only pick just one by specifiying the `capture` keyword argument.

```ruby
# only capture stdout.
System.run program, capture: :out
# => [#<Process::Status: pid 20421 exit 0>, "hello"]

# only capture stderr.
System.run program, capture: :err
# => [#<Process::Status: pid 20458 exit 0>, "world"]
```

Sometimes, it is also useful to capture both stdout _and_ stderr simultaneously.
Bear in mind, however, that stdout is buffered and thus might not appear if the
process dies before the buffer is flushed.

```ruby
# capture both stdout and stderr into the same string.
# stdout is buffered, stderr is not!
System.run program, capture: :both
# => [#<Process::Status: pid 20464 exit 0>, "worldhello"]
```

You can also specify a timeout interval after which System.run will kill
the process.

```ruby
# kill (send signal 9) process after the specified time.
program = %q{ruby -e "STDERR.print 'this can only end badly'; loop { sleep 1 }"}
System.run program, timeout: 2, capture: :both
# ...
# => [#<Process::Status: pid 20507 SIGKILL (signal 9)>, "this can only end badly"]
```

If outright killing the process is too harsh for you, or you want to do some
extra things like logging the timeout, you can specify a callable object that
will get called when the timeout expires. This callable will receive one argument,
the process id of the spawned child.

```ruby
# override default action with sending SIGTERM and setting a control variable.
state = :everything_is_great
System.run program, timeout: 2, capture: :both, on_timeout: ->(pid) do
  state = :oh_no
  Process.kill 15, pid
end
# ...
# => [#<Process::Status: pid 20519 SIGTERM (signal 15)>, "this can only end badly"]
```

You can temporarily set some environment variables that will be accessible to
the child process. Keys and values will be converted by System.run for you, don't
worry about that.

```ruby
# set some environment variable.
program = %{ruby -e "STDERR.print ENV['hello']; STDOUT.print Dir.pwd"}
System.run program, capture: :err, env: {'hello' => 2}
# => [#<Process::Status: pid 20540 exit 0>, "2"]
```

You can also specify the directory which shall be the working directory
for the child process.

```ruby
# set working dir.
System.run program, capture: :out, cwd: Dir.tmpdir
# => [#<Process::Status: pid 20545 exit 0>, "/tmp"]
```

If the output is too large to be loaded into memory or you want to keep the
output, you can specify a file–or for default capture, two files–that
System.run should write to. System.run will rewind the file after writing.

```ruby
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
```

You can specify all options the same as when working with strings, System.run doesn't care.

```ruby
# everything works the same!
out = Tempfile.new 'out'
System.run program, file: out, capture: :both
# => #<Process::Status: pid 20591 exit 0>
out.read
# => "worldhello"
```

You can also supply text to be used as input for the child process by passing
the corresponding file object as `in` keyword parameter.

```ruby
# the in: option is passed directly to Kernel.spawn.
input = Tempfile.new.tap { |f| f.write('system_run'); f.rewind }
echo = %q{ruby -e "print STDIN.gets"}
System.run echo, in: input, capture: :out
# => [#<Process::Status: pid 20605 exit 0>, "system_run"]
```
