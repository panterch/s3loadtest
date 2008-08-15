AWS_ACCESS_KEY =  "Please read the README"
AWS_SECRET_KEY =  "Please read the README"
AWS_BUCKET_NAME = "Please read the README"
AWS_OBJECT_KEY =  "Please read the README"

require 'rubygems'
require 'benchmark'
require 'aws/s3'
include AWS::S3

class Stats
  def initialize
    @runs = []
    @total = {}
  end

  def to_s
  <<-EOF

Current Statistics
------------------

#{@total[:runs]} runs total
#{@total[:failed]} failed
#{@total[:successful]} successful

#{@total[:bytes]} bytes successfully transfered
#{@total[:rate]} bytes/s average rate when successful
#{@total[:min_rate]} bytes/s minimal rate when successful
#{@total[:max_rate]} bytes/s maximal rate when successful

  EOF
  end

  def record(run)
    @runs << run
    total = { :runs => @runs.size, :successful => 0, :failed => 0,
              :bytes => 0, :time => 0.0 }
    rates = []
    @runs.each do |run|
      if run[:error]
        total[:failed] += 1
        next
      end
      total[:successful] += 1
      total[:bytes]      += run[:size]
      total[:time]       += run[:time] 
      rates << run[:size] / run[:time]
    end
    total[:rate] = total[:bytes] / total[:time]
    total[:min_rate] = rates.min
    total[:max_rate] = rates.max
    @total = total
  end
end
stats = Stats.new

puts 'Establishing S3 connection...'
Base.establish_connection!(
  :access_key_id     => AWS_ACCESS_KEY,
  :secret_access_key => AWS_SECRET_KEY
)

s3 = S3Object.find AWS_OBJECT_KEY, AWS_BUCKET_NAME
while true
  run = {}
  run[:size] = s3.about['content-length'].to_i
  puts "Streaming #{run[:size]} bytes of data..."
  run[:time] = Benchmark.realtime do
    begin
      open('/dev/null', 'a') do |file|
        s3.value(:reload) do |segment|
          file.write segment
        end
      end
    rescue => exception
      run[:error] = exception.to_s
      puts "an exception happened: #{exception.to_s}"
    end
  end
  puts "Successfully downloaded #{run[:size]} bytes of data in #{run[:time]}s."
  stats.record run
  puts stats
end

puts 'Program end.'

