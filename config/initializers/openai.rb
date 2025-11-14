# Configure global OpenAI client settings from env.
OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_API_KEY", nil)
  config.log_errors = true
end
