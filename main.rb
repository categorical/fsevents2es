#!/usr/bin/env ruby


def fileabspath(f,relative=__FILE__)
    File.expand_path(f,File.dirname(relative))
end
ENV['BUNDLE_GEMFILE']=fileabspath 'Gemfile'
require 'bundler/setup'


class Main
    require_relative 'elastic/elastic'
    require_relative 'logging'
    require_relative 'config'
    require 'json'
    
   
     
    class<<self
        def main args
            
            Elastic.connect Config.elastic
            case true
            when args[0]=='--list'
                puts Elastic.indices
            when args[0]=='--delete'
                Elastic.deleteindex *args[1..-1]
            when args[0]=='--collect'||args[0]=='--dry'
                Config.instance_variable_set(:@debug,true) if args[0]=='--dry'
                require_relative 'fsevents'
                Fsevents.run
                Elastic.ensuretemplate
                Elastic.bulkindex Fsevents.parse
            when args[0]=='--template'
                Elastic.ensuretemplate
            when args[0]=='--clean' 
                Elastic.clean *args[1..-1]
            else
                Logging.info "hello"
            end
        end
    end
end

if __FILE__==$0
    #p Main.instance_variables
    #p Main.constants
    #p Main.class_variables
    Main.main ARGV
end






