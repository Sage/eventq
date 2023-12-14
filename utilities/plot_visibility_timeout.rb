require './../lib/eventq/eventq_aws/aws_calculate_visibility_timeout'
require 'csv'
require 'logger'

class PlotVisibilityTimeout
  # Folder where the plot results are saved
  PLOT_FOLDER = 'plot_results'

  def plot(settings)
    setup

    @plot_seconds                     = settings.fetch(:plot_seconds)
    @plot_min_timeout                 = settings.fetch(:plot_min_timeout)
    @plot_file_name                   = "#{PLOT_FOLDER}/plot_#{settings.values.join('__')}"

    @queue_allow_retry_back_off       = settings.fetch(:queue_allow_retry_back_off)
    @queue_allow_exponential_back_off = settings.fetch(:queue_allow_exponential_back_off)
    @queue_retry_back_off_weight      = settings.fetch(:queue_retry_back_off_weight)
    @queue_retry_jitter_ratio         = settings.fetch(:queue_retry_jitter_ratio)
    @queue_max_retry_delay            = settings.fetch(:queue_max_retry_delay)
    @queue_max_timeout                = settings.fetch(:queue_max_timeout)
    @queue_retry_back_off_grace       = settings.fetch(:queue_retry_back_off_grace)
    @queue_retry_delay                = settings.fetch(:queue_retry_delay)

    logger = Logger.new(STDOUT)

    @calculator = EventQ::Amazon::CalculateVisibilityTimeout.new(max_timeout: @queue_max_timeout, logger: logger)

    print_settings_list(settings)

    execute
  end

  private
  attr_reader :calculator

  def setup
    unless Dir.exist?(PLOT_FOLDER)
      Dir.mkdir(PLOT_FOLDER)
    end
  end

  def execute
    puts "Executing..."
    CSV.open("#{@plot_file_name}.csv", 'w') do |csv|
      csv << ['retry_counter', 'visibility_timeout', 'total_elapsed_time', ]

      retry_counter = 0
      total_elapsed_time = 0
      max_visibility_timeout = 0
      while(total_elapsed_time <= @plot_seconds) do
        retry_counter += 1

        visibility_timeout = calculate(retry_counter)

        if (visibility_timeout == 0)
          visibility_timeout = @plot_min_timeout
        end

        max_visibility_timeout = visibility_timeout
        total_elapsed_time += visibility_timeout
        total_elapsed_time = total_elapsed_time.round(2)

        csv << [retry_counter, visibility_timeout, total_elapsed_time]
      end

      print_output(retry_counter, max_visibility_timeout,total_elapsed_time)
    end
  end

  def calculate(retry_counter)
    calculator.call(
      retry_attempts:       retry_counter,
      queue_settings: {
        allow_retry_back_off:       @queue_allow_retry_back_off,
        allow_exponential_back_off: @queue_allow_exponential_back_off,
        max_retry_delay:            @queue_max_retry_delay,
        retry_back_off_grace:       @queue_retry_back_off_grace,
        retry_back_off_weight:      @queue_retry_back_off_weight,
        retry_jitter_ratio:         @queue_retry_jitter_ratio,
        retry_delay:                @queue_retry_delay
      }
    )
  end

  def print_settings_list(settings)
    settings_list = [
      "-" * 50,
      settings.map { |arr| "#{arr[0]} = #{arr[1]}" }.join("\n"),
      "-" * 50,
      "\n"
    ].join("\n")

    puts settings_list
    File.write("#{@plot_file_name}.txt", settings_list)
  end

  def print_output(retry_counter, max_visibility_timeout,total_elapsed_time)
    output_details = [
      "Completed:",
      "• #{retry_counter} total retries.",
      "• #{retry_counter - @queue_retry_back_off_grace} total retries after grace period.",
      "• #{max_visibility_timeout} max timeout in seconds",
      "• #{total_elapsed_time} total elapsed time in seconds"
    ].join("\n")

    puts output_details
    puts "=> #{@plot_file_name}.csv"

    File.open("#{@plot_file_name}.txt", 'a') { |f| f.write(output_details) }
  end
end

settings = {
  # Sometimes the calculated timeout is zero so we must default to a value
  # since in real life the is no zero second connections.
  plot_min_timeout:                 0.03,       # 30ms which is the average connection time between worker and queue

  # The amount of time we should plot for.
  plot_seconds:                     72*60*60,   # simulate 72h
  queue_allow_retry_back_off:       true,       # enables backoff strategy
  queue_allow_exponential_back_off: false,      # disables exponential backoff strategy

  # The cap value for the queue retry
  queue_max_retry_delay:            1_500_000,  # will wait max 1500s
  queue_max_timeout:                43_200,     # 12h which AWS max message visibility timeout

  # Waiting period before the backoff strategy kicks in.
  # Multiply with query_retry_delay and divide by 60 to see how many minutes it will wait.
  queue_retry_back_off_grace:       30_000,     # wait 15min: (queue_retry_back_off_grace * queue_retry_delay)/60

  # Delay and retry for each queue iterations. The multiplier is necessary in case the calculated values
  # are insignificant between iterations.
  queue_retry_back_off_weight:      100,        # Backoff multiplier
  queue_retry_delay:                30,         # 30ms

  # Ratio of randomness allowed on retry delay to avoid a bulk of retries hitting again at the same time
  queue_retry_jitter_ratio:         0           # ratio for randomness on retry delay
}

PlotVisibilityTimeout.new.plot(settings)
