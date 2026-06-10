InertiaRails.configure do |config|
  # Tie the Inertia asset version to the Vite build so clients hard-reload
  # when the bundle changes.
  config.version = lambda { ViteRuby.digest }

  # Opt in to the InertiaRails 4.0 behaviour ahead of time (silences a deprecation).
  config.always_include_errors_hash = true
end
