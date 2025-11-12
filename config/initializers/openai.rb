if ENV['OPENAI_API_KEY']
  begin
    require 'openai'
    OPENAI_CLIENT = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  rescue LoadError
    Rails.logger.warn('[openai] ruby-openai gem not available; skipping client initialization')
  end
end

