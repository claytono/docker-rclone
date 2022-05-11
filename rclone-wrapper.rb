#!/usr/bin/env ruby

require "chronic_duration"
require "faraday"
require "open3"
require "uri"

$stdout.sync = true

class RcloneMetricsWrapper
  attr_reader :exit_code

  INSTANCE_PATH="/metrics/job/rclone/instance"
  UNITS_TABLE = {
    "k" => 1024,
    "m" => 1024 ** 2,
    "g" => 1024 ** 3,
    "t" => 1024 ** 4,
    "p" => 1024 ** 5,
  }
  def initialize
    unless ENV.key?('PUSH_GATEWAY')
      puts "PUSH_GATEWAY environment variable must be set to url"
      exit 1
    end
    @endpoint = ENV['PUSH_GATEWAY']

    unless ENV.key?('INSTANCE')
      puts "INSTANCE environment variable must be set to url"
      exit 1
    end
    @instance = ENV['INSTANCE']

    @uri = URI(@endpoint)
    @uri.path = File.join(INSTANCE_PATH, @instance)

    @transferred = @elapsed = @bytes = 0
  end

  def process(args)
    cmd = args.unshift('rclone')
    puts "Running: #{cmd.join(' ')}"
    start = Time.now
    Open3.popen2e(args.join(' ')) do |input, output, wait_thr|
      output.binmode
      output.each_line do |line|
        line.chomp!
        puts line
        # Match file count
        if m = line.match(/Transferred:\s+(\d+)\s*\/\s*\d+/)
          @transferred = m[1]
        end

        # Match bytes count
        if m = line.match(/Transferred:.+?(\d+\.\d+) (.?)Bytes/)
          @bytes = (m[1].to_f * UNITS_TABLE[m[2].downcase]).to_i
        end

        if m = line.match(/Elapsed time:\s+(\S+)/)
          @elapsed = ChronicDuration.parse(m[1], keep_zero: true)
          send_transfer_metrics
        end

        if m = line.match(/^Used:\s+(\d+\.?\d*)(\D+)/)
          used = (m[1].to_f * UNITS_TABLE[m[2].downcase]).to_i
          send_metric("rclone_bytes_used", "counter", used)
        end

        if m = line.match(/^Trashed:\s+(\d+\.?\d*)(\D+)/)
          trashed = (m[1].to_f * UNITS_TABLE[m[2].downcase]).to_i
          send_metric("rclone_bytes_trashed", "counter", trashed)
        end
      end
      rc = wait_thr.value
      send_metric("rclone_exit_code", "gauge", rc.exitstatus)
      send_metric("rclone_runtime", "gauge", Time.now.to_f - start.to_f)
      @exit_code = rc.exitstatus
    end
  end

  def send_metric(name, type, value)
    puts "Reporting below metrics to #{@uri}"
    metric = [
      "# TYPE #{name} #{type}",
      "#{name} #{value}"
    ].join("\n")
    puts metric

    conn = Faraday.new(url: @endpoint)
    resp = conn.post(@uri.path) do |req|
      req.body = metric + "\n"
    end
    puts "Response code: #{resp.status}"
  end

  def send_transfer_metrics
    metrics = [
      "# TYPE rclone_files_count counter",
      "rclone_files_count #{@transferred}",
      "# TYPE rclone_files_bytes counter",
      "rclone_files_bytes #{@bytes}",
      "# TYPE rclone_elapsed counter",
      "rclone_elapsed #{@elapsed}",
    ].join("\n")

    puts "Reporting below metrics to #{@uri}"
    puts metrics

    conn = Faraday.new(url: @endpoint)
    resp = conn.post(@uri.path) do |req|
      req.body = metrics + "\n"
    end
    puts "Response code: #{resp.status}"
  end
end



rmw = RcloneMetricsWrapper.new
rmw.process(ARGV)
exit(rmw.exit_code)

