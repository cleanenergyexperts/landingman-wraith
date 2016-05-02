require 'tempfile'
require 'yaml'

# CLI Module
module Middleman::Cli
  # The CLI Wraith class
  class Wraith < Thor::Group
    include Thor::Actions

    check_unknown_options!

    class_option :environment,
                 aliases: '-e',
                 default: ENV['MM_ENV'] || ENV['RACK_ENV'] || 'development',
                 desc: 'The environment Middleman will run under'
    class_option :verbose,
                 type: :boolean,
                 default: false,
                 desc: 'Print debug messages'
    class_option :production_url,
                 type: :string,
                 default: nil,
                 desc: 'The URL to the production site'
    class_option :staging_url,
                 type: :string,
                 default: nil,
                 desc: 'The URL to the staging site'
    class_option :directory,
                 type: :string,
                 default: 'screenshots',
                 desc: 'The directory to place the reports and screenshots in'
    class_option :mode,
                 type: :string,
                 default: 'diffs_first',
                 desc: 'The wraith mode to use to generate the screenshot report'

    def wraith
      require 'middleman-core'
      #require 'middleman/rack'
      #require 'middleman-core/rack'

      opts = {
        environment: options['environment'],
        debug: options['verbose']
      }

      @app = ::Middleman::Application.new do
        config[:environment] = opts[:environment].to_sym if opts[:environment]

        ::Middleman::Logger.singleton(opts[:debug] ? 0 : 1, opts[:instrumenting] || false)
      end
      paths = @app.sitemap.resources.select {|r| r.path.end_with?('.html') }.map do |r| 
        [r.path.gsub(/\//,'_').gsub(/[^0-9A-Za-z.\-]/, '_'), r.url]
      end.to_h

      production_url = options['production_url'] || @app.config.production_url
      if production_url.nil? || production_url.empty? then
        say("[ERROR] No production URL. Add to your config.rb: set :production_url, 'http://yourdomain.com'")
        exit(1)
      end
      staging_url = options['staging_url'] || @app.config.staging_url
      if staging_url.nil? || staging_url.empty? then
        say("[ERROR] No production URL. Add to your config.rb: set :staging_url, 'http://staging.yourdomain.com'")
        exit(1)
      end

      wraith_config = {
        "domains" => {
          "production" => production_url, 
          "staging" => staging_url
        }, 
        "paths" => paths, 
        "fuzz" => "20%", 
        "threshold" => 5, 
        "screen_widths" => [320, 640, 1024, 1280, 1366, 1920], 
        "browser" => "phantomjs", 
        "directory" => options['directory'] || "screenshots", 
        "mode" => options['mode'] || "diffs_first",
        "verbose" => options['verbose']
      }

      config_file = Tempfile.new(['wraith', '.yaml'])
      begin
        config_file.write(wraith_config.to_yaml)
        config_file.flush
        config_file.close

        say("=== Running Wraith ===")
        ::Landingman::WraithAdapter.new.capture(config_file.path)
      ensure
        config_file.unlink    # deletes the temp file
      end
    end

    # Add to CLI
    Base.register(self, 'wraith', 'wraith [options]', 'Run BBCs wraith against your Middleman application')
  end
end