# frozen_string_literal: true

require 'open3'

# Handler of redmine-task (docs/tasks.md). It does not load Rails: it checks
# the event and runs rake or rails runner as a child process.
module TaskHandler
  REDMINE_ROOT = '/var/task/redmine'
  COMMANDS = {
    'rake' => %w[bundle exec rake],
    'runner' => %w[bundle exec rails runner]
  }.freeze
  ALLOWED_ENV = %w[REDMINE_LANG MESSAGE_ID].freeze
  OUTPUT_LIMIT = 256 * 1024
  # Set by the runtime for its own gems; the child uses Redmine's bundle.
  RUNTIME_ENV = %w[RUBYLIB GEM_HOME GEM_PATH].freeze

  module_function

  def process(event:, context: nil) # rubocop:disable Lint/UnusedMethodArgument
    command, args, env = parse(event)
    child_env = RUNTIME_ENV.to_h { |name| [name, nil] }.merge(env)
    output = +''
    status = Open3.popen2e(child_env, *COMMANDS.fetch(command), *args, chdir: REDMINE_ROOT) do |stdin, out, wait|
      stdin.close
      out.each_line do |line|
        $stdout.write(line)
        output << line
        output = tail(output, OUTPUT_LIMIT * 2) if output.bytesize > OUTPUT_LIMIT * 2
      end
      wait.value
    end
    { 'exit_code' => status.exitstatus || 1, 'output' => tail(output, OUTPUT_LIMIT) }
  end

  def parse(event)
    raise ArgumentError, 'event must be an object' unless event.is_a?(Hash)

    ses = event.dig('Records', 0, 'ses')
    ses ? parse_ses(ses) : parse_command(event)
  end

  # A receipt rule passes the received mail; it is imported from S3.
  def parse_ses(ses)
    message_id = ses.dig('mail', 'messageId')
    raise ArgumentError, 'SES event without messageId' unless message_id.is_a?(String) && !message_id.empty?

    ['rake', ['redmine_serverless_ses:receive_mail'], { 'MESSAGE_ID' => message_id }]
  end

  def parse_command(event)
    command = event['command']
    raise ArgumentError, "command must be one of #{COMMANDS.keys.join(', ')}" unless COMMANDS.key?(command)

    args = event.fetch('args', [])
    raise ArgumentError, 'args must be a list of strings' unless args.is_a?(Array) && args.all?(String)

    [command, args, parse_env(event.fetch('env', {}))]
  end

  def parse_env(env)
    raise ArgumentError, 'env must be an object of strings' unless env.is_a?(Hash) && env.values.all?(String)

    unknown = env.keys - ALLOWED_ENV
    raise ArgumentError, "env not allowed: #{unknown.join(', ')}" unless unknown.empty?

    env
  end

  # The last bytes of text, starting at a character boundary.
  def tail(text, limit)
    bytes = text.b
    return text.dup.force_encoding(Encoding::UTF_8).scrub if bytes.bytesize <= limit

    bytes = bytes.byteslice(-limit, limit)
    start = 0
    start += 1 while start < bytes.bytesize && (bytes.getbyte(start) & 0xC0) == 0x80
    bytes.byteslice(start..).force_encoding(Encoding::UTF_8).scrub
  end
end
