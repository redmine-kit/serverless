# frozen_string_literal: true

require 'aws-sdk-ssm'

# Settings and secrets from SSM Parameter Store (docs/lambda.md#loading).
# config/additional_environment.rb calls it before the database connection
# and SECRET_KEY_BASE are read.
module ServerlessEnv
  NAME = /\A[A-Z][A-Z0-9_]*\z/

  module_function

  # Reads every parameter directly under path (such as /redmine/env/) into
  # ENV, with the last part of the name as the variable name. Variables that
  # are already set are kept, so that local tests can pass values directly.
  # Names that cannot be environment variables are skipped. Returns the
  # names read, in order.
  def load(path, client: Aws::SSM::Client.new)
    names = []
    client.get_parameters_by_path(path: path, recursive: false, with_decryption: true).each_page do |page|
      page.parameters.each do |parameter|
        name = parameter.name.delete_prefix(path)
        next unless NAME.match?(name)

        names << name
        ENV[name] ||= parameter.value
      end
    end
    names
  end
end
