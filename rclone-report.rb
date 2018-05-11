#!/usr/bin/env ruby

require "chronic_duration"
require "faraday"
require "uri"

$stdout.sync = true

class RcloneMetrics
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
  def process!
    ARGF.each_line do |line|
      puts line
      line.chomp!
      if m = line.match(/Transferred:\s+(\d+)\s+$/)
        @transferred = m[1]
      end

      if m = line.match(/Transferred:\s+(\d+\.\d+) (.?)Bytes/)
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



RcloneMetrics.new.process!

