begin
  require 'aws-sdk-transcribeservice'
rescue LoadError
  Rails.logger.warn('[aws] aws-sdk-transcribeservice not available; Transcribe integration disabled')
end

if defined?(Aws)
  Aws.config.update(
    region: ENV['AWS_REGION'],
    credentials: Aws::Credentials.new(
      ENV['AWS_ACCESS_KEY_ID'],
      ENV['AWS_SECRET_ACCESS_KEY']
    )
  )
end
