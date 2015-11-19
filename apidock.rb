#! /usr/bin/env ruby

require_relative './websites'

module ApiDock
  APIDOCK_URL = "http://apidock.com"

  class Handler < ::Websites::CommandHandler
    protected

    def generate_command(args)
      subsite = args.shift
      cmdclass = case subsite
                 when "rb", "ruby"
                   generate_ruby_command(args)
                 when "r", "rails"
                   generate_rails_command(args)
                 when "rs", "rspec"
                   generate_rspec_command(args)
                 else
                   nil
                 end

      if cmdclass
        cmdclass.new(args:args)
      else
        ::Websites::WebCommand.new(url: APIDOCK_URL)
      end
    end

    private

    def generate_ruby_command(args)
      if args.first == "q"
        args.shift
        RubyQuery
      else
        RubyLookup
      end
    end

    def generate_rails_command(args)
      if args.first == "q"
        args.shift
        RailsQuery
      else
        RailsLookup
      end
    end

    def generate_rspec_command(args)
      if args.first == "q"
        args.shift
        RspecQuery
      else
        RspecLookup
      end
    end
  end

  class Query < ::Websites::WebCommand
    def generate_url(args)
      "#{APIDOCK_URL}/#{prefix}/search?query=#{args.first}"
    end
  end

  class RubyQuery < Query
    def prefix; "ruby"; end
  end

  class RailsQuery < Query
    def prefix; "rails"; end
  end

  class RspecQuery < Query
    def prefix; "rspec"; end
  end

  class Lookup < ::Websites::WebCommand
    def generate_url(args)
      "#{APIDOCK_URL}/#{prefix}/#{args.first}"
    end
  end

  class RubyLookup < Lookup
    def prefix; "ruby"; end
  end

  class RailsLookup < Lookup
    def prefix; "rails"; end
  end

  class RspecLookup < Lookup
    def prefix; "rspec"; end
  end
end
