# frozen_string_literal: true

# Unit tests of the redmine-task handler. bin/test-image runs them inside the
# image, with the image's Ruby. Running tasks is checked there as well.
require 'minitest/autorun'
require_relative '../../image/handler' unless defined?(TaskHandler)

class TaskHandlerTest < Minitest::Test
  def test_rake_with_allowed_env
    command, args, env = TaskHandler.parse(
      'command' => 'rake', 'args' => ['redmine:load_default_data'], 'env' => { 'REDMINE_LANG' => 'ja' }
    )
    assert_equal ['rake', ['redmine:load_default_data'], { 'REDMINE_LANG' => 'ja' }], [command, args, env]
  end

  def test_runner_without_args_or_env
    assert_equal ['runner', [], {}], TaskHandler.parse('command' => 'runner')
  end

  def test_ses_event_imports_the_message
    event = { 'Records' => [{ 'ses' => { 'mail' => { 'messageId' => 'abc123' } } }] }
    assert_equal ['rake', ['redmine_serverless_ses:receive_mail'], { 'MESSAGE_ID' => 'abc123' }],
                 TaskHandler.parse(event)
  end

  def test_rejects_ses_event_without_message_id
    assert_raises(ArgumentError) { TaskHandler.parse('Records' => [{ 'ses' => { 'mail' => {} } }]) }
  end

  def test_rejects_unknown_command
    assert_raises(ArgumentError) { TaskHandler.parse('command' => 'sh', 'args' => ['-c', 'id']) }
  end

  def test_rejects_env_outside_the_allowed_names
    %w[REDMINE_DB_HOST REDMINE_DB_PASSWORD RUBYOPT PATH].each do |name|
      assert_raises(ArgumentError) { TaskHandler.parse('command' => 'rake', 'env' => { name => 'x' }) }
    end
  end

  def test_rejects_args_that_are_not_strings
    assert_raises(ArgumentError) { TaskHandler.parse('command' => 'rake', 'args' => 'db:migrate') }
    assert_raises(ArgumentError) { TaskHandler.parse('command' => 'rake', 'args' => [1]) }
  end

  def test_rejects_env_values_that_are_not_strings
    assert_raises(ArgumentError) { TaskHandler.parse('command' => 'rake', 'env' => { 'REDMINE_LANG' => 1 }) }
  end

  def test_rejects_event_that_is_not_an_object
    assert_raises(ArgumentError) { TaskHandler.parse('rake') }
  end

  def test_tail_keeps_short_text
    assert_equal 'done', TaskHandler.tail('done', 10)
  end

  def test_tail_keeps_the_end
    assert_equal 'world', TaskHandler.tail('hello world', 5)
  end

  def test_tail_does_not_cut_a_character
    text = "あいう\n" # 3 bytes per character
    tail = TaskHandler.tail(text, 5)
    assert_predicate tail, :valid_encoding?
    assert_equal "う\n", tail
  end

  def test_tail_of_invalid_bytes_is_valid_utf8
    assert_predicate TaskHandler.tail("ok \xFF".b, 10), :valid_encoding?
  end
end
