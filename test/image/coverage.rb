# frozen_string_literal: true

# Line coverage of the image's own Ruby files (image/*.rb in the repository,
# /var/task/*.rb in the image) with Ruby's Coverage, written in LCOV to
# $COVERAGE_FILE for Codecov. Loaded before the files it measures; it writes
# after the tests, which run at exit too.
require 'coverage'

Coverage.start(lines: true)
at_exit do
  output = ENV.fetch('COVERAGE_FILE', nil)
  next unless output

  File.open(output, 'w') do |file|
    Coverage.result.each do |path, result|
      next unless File.dirname(path) == '/var/task' && path.end_with?('.rb')

      lines = result[:lines]
      file.puts "SF:image/#{File.basename(path)}"
      lines.each_with_index { |count, index| file.puts "DA:#{index + 1},#{count}" if count }
      file.puts "LF:#{lines.compact.size}", "LH:#{lines.compact.count(&:positive?)}", 'end_of_record'
    end
  end
end
