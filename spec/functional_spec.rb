here = File.expand_path(File.dirname(__FILE__))
require "#{here}/spec_helper.rb"
require 'tmpdir'

describe "the rerun command" do
  before do
    STDOUT.sync = true

    @dir = Dir.tmpdir + "/#{Time.now.to_i}"
    FileUtils.mkdir_p(@dir)
    @file = "#{@dir}/inc.txt"

    @dir1 = File.join(@dir, "dir1")
    FileUtils.mkdir_p(@dir1)
    @app_file = File.join(@dir1, "foo.rb")

    @app_file2 = File.join(@dir1, "bar.rb")

    @dir2 = File.join(@dir, "dir2")
    FileUtils.mkdir_p(@dir2)
    @app_file3 = File.join(@dir2, "baz.rb")

    touch @app_file
    launch_inc
  end

  after do
    timeout(4) {
      Process.kill("INT", @pid) && Process.wait(@pid) rescue Errno::ESRCH
    }
  end

  def launch_inc
    @pid = fork do
      root = File.dirname(__FILE__) + "/.."
      exec("#{root}/bin/rerun -d '#{@dir1},#{@dir2}' ruby #{root}/inc.rb #{@file}")
    end
    timeout(10) { sleep 0.5 until File.exist?(@file) }
    sleep 4  # let inc get going
  end

  def read
    File.open(@file, "r") do |f|
      launched_at = f.gets.to_i
      count = f.gets.to_i
      [launched_at, count]
    end
  end

  def current_count
    launched_at, count = read
    count
  end

  def touch(file = @app_file)
    puts "#{Time.now.strftime("%T")} touching #{@app_file}"
    File.open(file, "w") do |f|
      f.puts Time.now
    end
  end

  def type char
    # todo: send a character to stdin of the rerun process
  end

  it "increments a test file at least once per second" do
    x = current_count
    sleep 1
    y = current_count
    y.should be > x
  end

  it "restarts its target when an app file is modified" do
    first_launched_at, count = read
    touch @app_file
    sleep 4
    second_launched_at, count = read

    second_launched_at.should be > first_launched_at
  end

  it "restarts its target when an app file is created" do
    first_launched_at, count = read
    touch @app_file2
    sleep 4
    second_launched_at, count = read

    second_launched_at.should be > first_launched_at
  end

  it "restarts its target when an app file is created in the second dir" do
    first_launched_at, count = read
    touch @app_file3
    sleep 4
    second_launched_at, count = read

    second_launched_at.should be > first_launched_at
  end

  #it "sends its child process a SIGINT to restart"

  it "dies when sent a control-C (SIGINT)" do
    Process.kill("INT", @pid)
    timeout(6) {
      Process.wait(@pid) rescue Errno::ESRCH
    }
  end

  #it "accepts a key press"
end


