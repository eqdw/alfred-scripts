#! /usr/bin/env ruby

module Websites
  class CommandHandler
    attr_reader :command

    def initialize(command:nil, args:[])
      @command = command || generate_command(args)
    end

    def run
      @command.run
    end
  end

  class WebHandler < CommandHandler
    attr_reader :url

    def initialize(args:"http://eqdw.net")
      @url = parse_args(args)
      super command: WebCommand.new(url:url)
    end

    private

    # can be string, hash, or array
    def parse_args(args)
      case args
      when String
        args
      when Hash
        args[:url]
      when Array
        args.first
      end
    end
  end

  class Runner
    attr_reader :handler

    def self.run(handler, args={})
      self.new(handler, args).run
    end

    def initialize(handler, args={})
      @handler = handler.new(args:args)
    end

    def run
      @handler.run
    end
  end

  class WebCommand
    attr_reader :url

    def initialize(url:nil, args:[])
      @url = url || generate_url(args)
    end

    def generate_url(_args); raise "Not Implemented"; end

    def run
      `open #{url}`
    end
  end
end
