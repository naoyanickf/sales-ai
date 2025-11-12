CarrierWave.configure do |config|
  config.cache_dir = Rails.root.join("tmp", "uploads")
  config.remove_previously_stored_files_after_update = false

  use_fog = Rails.env.production? || ENV["AWS_S3_BUCKET"].present?

  if use_fog
    config.storage = :fog
    config.fog_provider = "fog/aws"
    config.fog_public = false

    config.fog_credentials = {
      provider: "AWS",
      aws_access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
      aws_secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
      region: ENV.fetch("AWS_REGION", "ap-northeast-1")
    }

    config.fog_directory = ENV.fetch("AWS_S3_BUCKET")
    config.asset_host = ENV["ASSET_HOST"].presence
    config.fog_attributes = { "Cache-Control" => "max-age=315576000" }
  else
    config.storage = :file
    config.enable_processing = !Rails.env.test?
  end
end
