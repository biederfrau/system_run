#!/usr/bin/env ruby
# encoding: utf-8

$:.push '../lib'
require 'rspec'
require 'system_run'

RSpec.describe System, ".run" do
  context "basic capturing of output" do
    program = %q{ruby -e "STDOUT.print 'hello'; STDERR.print 'world'"}

    it "can capture stdout and stderr separately" do
      status, stdout, stderr = System.run program

      expect(status.exitstatus).to eq 0
      expect(stdout).to eq('hello')
      expect(stderr).to eq('world')
    end

    it "can discard stderr" do
      status, stdout = System.run program, capture: :out
      expect(status.exitstatus).to eq 0
      expect(stdout).to eq('hello')
    end

    it "can discard stdout, too" do
      status, stderr = System.run program, capture: :err
      expect(status.exitstatus).to eq 0
      expect(stderr).to eq('world')
    end

    it "can merge both streams into one" do
      status, all = System.run program, capture: :both
      expect(status.exitstatus).to eq(0)
      expect(all).to eq('worldhello')
    end
  end

  context "setting a timeout on subprocess" do
    program = %q{ruby -e "STDERR.print 'this can only end badly'; loop { sleep 2 }"}

    it "will timeout after n seconds, preserving output so-far, and kill process" do
      status, all = System.run program, timeout: 2, capture: :both

      expect(status.signaled?).to be true
      expect(status.termsig).to eq 9
      expect(all).to eq('this can only end badly')
    end

    it "will timeout after n seconds and execute a custom action" do
      state = :ok
      status, all = System.run program, timeout: 2, capture: :both, on_timeout: ->(pid) do
        state = :err
        Process.kill 15, pid
      end

      expect(state).to eq(:err)
      expect(status.signaled?).to be true
      expect(status.termsig).to eq 15
      expect(all).to eq('this can only end badly')
    end
  end

  context "setting environment variables and changing directory prior to executing" do
    program = %{ruby -e "STDERR.print ENV['hello']; STDOUT.print Dir.pwd"}

    it "can set environment variables" do
      status, stderr = System.run program, capture: :err, env: {'hello' => 2}

      expect(status.exitstatus).to eq(0)
      expect(stderr).to eq('2')
    end

    it "can switch working directory" do
      status, stdout = System.run program, capture: :out, cwd: Dir.tmpdir

      expect(status.exitstatus).to eq(0)
      expect(stdout).to eq(Dir.tmpdir)
    end
  end

  context "reading and writing to files" do
    program = %q{ruby -e "STDOUT.print 'hello'; STDERR.print 'world'"}

    it "can redirect output to files" do
      out = Tempfile.new 'out'
      err = Tempfile.new 'err'

      status = System.run program, file: [out, err]

      expect(status.exitstatus).to eq(0)
      expect(out.read).to eq('hello')
      expect(err.read).to eq('world')

      [out, err].each { |f| f.close; f.unlink }
    end

    it "works the same as with string, e.g. merging streams" do
      out = Tempfile.new 'out'

      status = System.run program, file: out, capture: :both

      expect(status.exitstatus).to eq(0)
      expect(out.read).to eq('worldhello')
      out.close; out.unlink
    end

    it "can read input provided in a file" do
      input = Tempfile.new.tap { |f| f.write('system_run'); f.rewind }

      echo = %q{ruby -e "print STDIN.gets"}
      status, out = System.run echo, in: input, capture: :out

      expect(status.exitstatus).to eq(0)
      expect(out).to eq('system_run')
    end
  end
end
