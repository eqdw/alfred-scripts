#!/usr/bin/env ruby

require_relative './urls'
require_relative './websites'

require 'forwardable'

module Github
  class Handler < ::Websites::CommandHandler
    attr_reader :repo_abbr

    def initialize(args: args)
      @repo_abbr = args.shift

      if repo_abbr
        super args: args
      end
    end

    protected

    # supported commands
    # <null>  #=> open repo
    # <hash>  #=> open specific commit
    # c(ommit(s)) #=> open list of commits, or specific commit
    # p(ull(s))   #=> open list of pulls, or specific pull
    # r(ef)       #=> open specific ref
    # pa(th)      #=> open specific path
    # f(ile)      #=> open specific file
    # d(iff) | pr #=> diff two things
    # h(istory)   #=> open history
    # b(lame)     #=> open blame for file
    def generate_command(args)
      return OpenRepo.new(repo_abbr) if args.empty?

      cmdstr = args.shift

      cmdclass = case cmdstr
                  when "c", "commit", "commits"
                    Commit
                  when "p", "pull", "pulls"
                    Pull
                  when "r", "ref"
                    Ref
                  when "pa", "path"
                    Path
                  when "f", "file"
                    File
                  when "d", "diff", "pr"
                    Diff
                  when "h", "history"
                    History
                  when "b", "blame"
                    Blame
                  else # called as `gh <repo> <commit>`
                    nil
                  end

      if cmdclass
        cmdclass.new(repo_abbr, args)
      else # hard coded case for looking up commits
        Commit.new(repo_abbr, [cmdstr])
      end
    end
  end

  class GithubCommand < ::Websites::WebCommand
    extend ::Forwardable

    def_delegators :urls, :repo, :expand_ref

    attr_reader :urls

    def initialize(repo_abbr, args=[])
      @urls = Urls.new(repo_abbr)

      super( url: generate_url(repo, args) )
    end
  end

  # `gh df` #=> "http://github.com/eqdw/dotfiles"
  class OpenRepo < GithubCommand
    def generate_url(repo, args)
      repo
    end
  end

  # `gh df commits`        #=> http://github.com/eqdw/dotfiles/commits
  # `gh df commits <hash>` #=> http://github.com/eqdw/dotfiles/commit/<hash>
  class Commit < GithubCommand
    def generate_url(repo, args)
      case args.length
      when 0
        "#{repo}/commits"
      when 1
        "#{repo}/commit/#{args.first}"
      end
    end
  end

  # `gh df pulls`          #=> http://github.com/eqdw/dotfiles/pulls
  # `gh df pulls <author>` #=> http://github.com/eqdw/dotfiles/pulls/<author>
  # `gh df pulls <num>`    #=> http://github.com/eqdw/dotfiles/pull/<num>
  class Pull < GithubCommand
    def generate_url(repo, args)
      case args.length
      when 0
        "#{repo}/pulls"
      when 1
        is_num = (args.first.to_i != 0) # non-numbers get turned into 0
        if is_num
          "#{repo}/pull/#{args.first}"
        else
          "#{repo}/pulls/#{args.first}"
        end
      end
    end
  end

  # `gh df ref <ref>`   #=> http://github.com/eqdw/dotfiles/tree/<ref>
  class Ref < GithubCommand
    def generate_url(repo, args)
      "#{repo}/tree/#{urls.expand_ref(args)}"
    end
  end

  # `gh df path <path>`               #=> http://github.com/eqdw/dotfiles/tree/master/<path>
  # `gh df path <ref> <path>`         #=> http://github.com/eqdw/dotfiles/tree/<ref>/<path>
  # `gh df path <path> history`       #=> http://github.com/eqdw/dotfiles/commits/master/<path>
  # `gh df path <ref> <path> history` #=> http://github.com/eqdw/dotfiles/commits/<ref>/<path>
  class Path < GithubCommand
    def generate_url(repo, args)

      # alias for history
      if ["h", "history"].include?(args.last)
        args.pop
        History.new(repo, args).generate_url
      else
        case args.length
        when 1
          ref  = "master"
          path = args.last
        when 2
          ref  = urls.expand_ref(args)
          path = args.last
        end

        "#{repo}/tree#{ref}/#{path}"
      end
    end
  end

  # `gh df file <path>`               #=> http://github.com/eqdw/dotfiles/blob/master/<path>
  # `gh df file <ref> <path>`         #=> http://github.com/eqdw/dotfiles/blob/<ref>/<path>
  # `gh df file <path> history`       #=> http://github.com/eqdw/dotfiles/commits/master/<path>
  # `gh df file <ref> <path> history` #=> http://github.com/eqdw/dotfiles/commits/<ref>/<path>
  # `gh df file <path> blame`         #=> http://github.com/eqdw/dotfiles/blame/master/<path>
  # `gh df file <ref> <path> blame`   #=> http://github.com/eqdw/dotfiles/blame/<ref>/<path>
  class File < GithubCommand
    def generate_url(repo, args)
      # alias for history
      if    [ "h", "history" ].include?(args.last)
        args.pop
        History.new(repo, args).generate_url
      # alias for blame
      elsif [ "b",   "blame" ].include?(args.last)
        args.pop
        Blame.new(repo, args).generate_url
      else
        case args.length
        when 1
          ref  = "master"
          path = args.last
        when 2
          ref  = urls.expand_ref(args)
          path = args.last
        end

        "#{repo}/blob/#{ref}/#{path}"
      end
    end
  end

  # `gh df diff <start> <end>` #=> http://github.com/eqdw/dotfiles/compare/<start>...<end>
  # `gh df pr <ref>`           #=> http://github.com/eqdw/dotfiles/compare/<ref> #useful for PRs
  #
  # cannot support spaces in the ref shortcut argument
  # `gh df pf at123` is supported
  # `gh df pf at 123` is not
  class Diff < GithubCommand
    def generate_url(repo, args)
      case args.length
      when 1
        "#{repo}/compare/#{urls.expand_ref(args.first)}"
      when 2
        "#{repo}/compare/#{args.first}...#{args.last}"
      end
    end
  end

  # `gh df history <path>`       #=> http://github.com/eqdw/dotfiles/commits/master/<path>
  # `gh df history <ref> <path>` #=> http://github.com/eqdw/dotfiles/commits/<ref>/<path>
  class History < GithubCommand
    def generate_url(repo, args)
      case args.length
      when 1
        ref  = "master"
        path = args.last
      when 2
        ref  = urls.expand_ref(args)
        path = args.last
      end

      "#{repo}/commits/#{ref}/#{path}"
    end
  end

  # `gh df blame <file>`       #=> http://github.com/eqdw/dotfiles/blame/master/<file>
  # `gh df blame <ref> <file>` #=> http://github.com/eqdw/dotfiles/blame/<ref>/<file>
  class Blame < GithubCommand
    def generate_url(repo, args)
      case args.length
      when 1
        ref  = "master"
        path = args.last
      when 2
        ref  = urls.expand_ref(args)
        path = args.last
      end

    "#{repo}/blame/#{ref}/#{file}"
    end
  end
end
