namespace :admin do
  desc "Set the admin password (stores a bcrypt digest in encrypted credentials)"
  task :set_password, [ :password ] => :environment do |_t, args|
    password = args[:password].presence || ENV["ADMIN_PASSWORD"].presence
    abort "Usage: bin/rails 'admin:set_password[your-password]'  (or ADMIN_PASSWORD=… bin/rails admin:set_password)" if password.blank?

    enc = Rails.application.encrypted(
      Rails.root.join("config/credentials.yml.enc"),
      key_path: Rails.root.join("config/master.key")
    )
    config = YAML.safe_load(enc.read.presence || "") || {}
    config["admin_password_digest"] = BCrypt::Password.create(password).to_s
    enc.write(config.to_yaml)

    puts "Stored admin_password_digest in credentials. You can now sign in at /admin/login."
  end
end
