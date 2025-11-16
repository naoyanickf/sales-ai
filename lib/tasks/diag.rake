namespace :diag do
  desc "Check AWS S3 and Transcribe configuration/connectivity"
  task aws: :environment do
    puts "[diag:aws] Checking AWS configuration..."
    required = %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_S3_BUCKET]
    missing = required.select { |k| ENV[k].to_s.strip.empty? }
    if missing.any?
      puts "[diag:aws] Missing ENV: #{missing.join(', ')}"
    else
      puts "[diag:aws] ENV looks present: #{required.join(', ')}"
    end

    begin
      require 'aws-sdk-s3'
      s3 = Aws::S3::Client.new
      resp = s3.list_buckets
      bucket_names = resp.buckets.map(&:name)
      puts "[diag:aws] S3 reachable. Buckets: #{bucket_names.take(5).join(', ')}#{' ...' if bucket_names.size > 5}"
      if ENV['AWS_S3_BUCKET'].present?
        exist = bucket_names.include?(ENV['AWS_S3_BUCKET'])
        puts "[diag:aws] Target bucket '#{ENV['AWS_S3_BUCKET']}' exists? #{exist}"
      end
    rescue NameError
      puts "[diag:aws] aws-sdk-s3 not loaded. Add gem or remove require: false"
    rescue => e
      puts "[diag:aws] S3 check failed: #{e.class} #{e.message}"
    end

    begin
      require 'aws-sdk-transcribeservice'
      transcribe = Aws::TranscribeService::Client.new
      transcribe.list_transcription_jobs(max_results: 1)
      puts "[diag:aws] Transcribe reachable."
    rescue NameError
      puts "[diag:aws] aws-sdk-transcribeservice not loaded. Add gem or remove require: false"
    rescue => e
      puts "[diag:aws] Transcribe check failed: #{e.class} #{e.message}"
    end
  end

  desc "Check OpenAI configuration/connectivity"
  task openai: :environment do
    puts "[diag:openai] Checking OpenAI configuration..."
    api_key = ENV['OPENAI_API_KEY']
    if api_key.to_s.strip.empty?
      puts "[diag:openai] Missing ENV: OPENAI_API_KEY"
    else
      masked = api_key[0,8] + '...' + api_key[-4,4]
      puts "[diag:openai] OPENAI_API_KEY present (#{masked})"
    end

    begin
      client = OpenAI::Client.new
      # Lightweight call: list models or simple embed
      models = client.models.list
      names = Array(models.dig('data')).map { |m| m['id'] }.take(5)
      puts "[diag:openai] API reachable. Sample models: #{names.join(', ')}"
    rescue => e
      puts "[diag:openai] API check failed: #{e.class} #{e.message}"
    end
  end

  desc "List ExpertKnowledge and transcription statuses around a timestamp"
  task :transcriptions, [:at, :window_minutes] => :environment do |_, args|
    at = begin
      args[:at].present? ? Time.zone.parse(args[:at]) : Time.current
    rescue
      Time.current
    end
    window = (args[:window_minutes] || 10).to_i
    from = at - window.minutes
    to = at + window.minutes

    puts "[diag:transcriptions] Window: #{from} .. #{to}"
    eks = ExpertKnowledge.where(created_at: from..to).includes(:sales_expert, :transcription_job, :transcription)
    if eks.none?
      puts "[diag:transcriptions] No ExpertKnowledge in window."
    else
      eks.order(created_at: :asc).each do |ek|
        puts "- EK##{ek.id} #{ek.file_name} (#{ek.content_type}) by #{ek.uploader&.name} at #{ek.created_at}"
        puts "  sales_expert: #{ek.sales_expert&.name} (id=#{ek.sales_expert_id})"
        puts "  transcription_status: #{ek.transcription_status} completed_at=#{ek.transcription_completed_at}"
        if (job = ek.transcription_job)
          puts "  job: status=#{job.status} external_job_id=#{job.external_job_id} error=#{job.error_message}"
        else
          puts "  job: (none)"
        end
        if (t = ek.transcription)
          puts "  transcription: id=#{t.id} text_len=#{t.full_text.to_s.length} segments=#{t.segments.count}"
        else
          puts "  transcription: (none)"
        end
      end
    end
  end
end
