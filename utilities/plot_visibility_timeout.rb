require './../lib/eventq/eventq_aws/aws_calculate_visibility_timeout'
require 'csv'
require 'logger'

class PlotVisibilityTimeout
  def plot(settings)
    @plot_seconds                = settings.fetch(:plot_seconds)
    @plot_min_timeout            = settings.fetch(:plot_min_timeout)
    @plot_file_name              = "plot_results/plot_#{settings.values.join('__')}"

    @queue_allow_retry_back_off  = settings.fetch(:queue_allow_retry_back_off)
    @queue_back_off_weight       = settings.fetch(:queue_back_off_weight)
    @queue_max_retry_delay       = settings.fetch(:queue_max_retry_delay)
    @queue_max_timeout           = settings.fetch(:queue_max_timeout)
    @queue_retry_back_off_grace  = settings.fetch(:queue_retry_back_off_grace)
    @queue_retry_delay           = settings.fetch(:queue_retry_delay)

    logger = Logger.new(STDOUT)

    @calculator = EventQ::Amazon::CalculateVisibilityTimeout.new(max_timeout: @queue_max_timeout, logger: logger)

    print_settings_list(settings)

    execute
  end

  private
  attr_reader :calculator

  def execute
    puts "Executing..."
    CSV.open("#{@plot_file_name}.csv", 'w') do |csv|
      csv << ['retry_counter', 'visibility_timeout', 'total_elapsed_time', ]

      retry_counter = 0
      total_elapsed_time = 0
      max_visibility_timeout = 0
      while(total_elapsed_time <= @plot_seconds) do
        retry_counter += 1

        visibility_timeout = calculator.call(
          retry_attempts:       retry_counter,
          queue_settings: {
            allow_retry_back_off: @queue_allow_retry_back_off,
            back_off_weight:      @queue_back_off_weight,
            max_retry_delay:      @queue_max_retry_delay,
            retry_back_off_grace: @queue_retry_back_off_grace,
            retry_delay:          @queue_retry_delay,
          }
        )

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
  plot_min_timeout:           0.03,       # in case the returned timeout is zero, default to 30ms which is the average connection time between worker and queue
  plot_seconds:               72*60*60, # simulate 72h
  queue_allow_retry_back_off: true,       # enables backoff strategy
  queue_back_off_weight:      100,        # Backoff multiplier
  queue_max_retry_delay:      1_500_000,  # will wait max 1500s
  queue_max_timeout:          43_200,     # 12h which AWS max message visibility timeout
  queue_retry_back_off_grace: 20_000,     # will wait 15min before starting to backoff
  queue_retry_delay:          30          # 30ms
}

PlotVisibilityTimeout.new.plot(settings)