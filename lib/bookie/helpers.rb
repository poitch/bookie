require 'yaml'
module Bookie
    module Helpers 
        def self.is_numeric?(obj) 
            obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
        end
    end
end

def config
    rcfile = ENV['BOOKIE_CONFIG'] || Dir.home + '/.bookie.yml'
    if File.exists? rcfile
        @config ||= YAML.load_file(rcfile)
    else
        {}
    end
end

