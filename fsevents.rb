
module Fsevents
    require_relative 'logging'
    require_relative 'config'
    require 'date'


    class<<self
        def run
            require 'open3'
            std0,@std1,std2,waitt=Open3.popen3('fswatch -txnf %s /')
            std0.close
            std2.close
            pid=waitt.pid
            Logging.info "Started process: #{pid}"

            at_exit do
                Logging.debug "Is std1 closed? #{@std1.closed?}"
                @std1.close
            end
            
            return 
            @std1.close 
            @std1,w=IO.pipe
            pid=fork do
                # How to redirect this process's IO?     
                w.puts 'hello'
                exec 'fswatch -txnf %s /'
            end
            Logging.info "Started process: #{pid}"
            w.close
            Process.detach pid
            at_exit do
                Process.kill 'HUP',pid
            end

        end
        

        def parse
            exclude=excludepaths
            en=Enumerator.new do |en|
                @std1.each_line do |l|
                    begin
                        /^(?<ts>\d+) (?<file>.+) (?<tags>\d+)$/.match l do |m|
                            ts=m[:ts].to_i
                            f=m[:file]
                            next if exclude.call(f)
                            msg={
                                timestamp: ts,
                                '@timestamp': Time.at(ts).utc.to_datetime.iso8601,
                                file: f,
                                dirname: File.dirname(f),
                                basename: File.basename(f),
                                tags: parsetags(m[:tags].to_i),
                                #tags: m[:tags],
                                bucket: parsebucket(f),
                                _type: 'fsevents',
                            }
                            en.yield msg
                        end
                    rescue=>e
                        # in `match': invalid byte sequence in US-ASCII (ArgumentError)
                        Logging.error e
                    end
                end
            end
        end

        private
        def parsetags n
            bits=%i'
                PlatformSpecific
                Created
                Updated
                Removed
                Renamed
                OwnerModified
                AttributeModified
                MovedFrom
                MovedTo
                IsFile
                IsDir
                IsSymLink
                Link'
            tags=[]
            for i in 0...bits.size
                f=2**i
                if n&f==f; tags<<bits[i] end    
            end
            tags
        end

        def parsebucket f
            parts=f.sub(/^\//,'').split(/\/+/)[0,3]
                .map{|p| p.gsub(/[^a-zA-Z0-9]/,'').downcase}
                .reject{|p| p.empty?}
            parts.join('-')
        end

        def excludepaths
            paths=Config.fsevents[:excludepaths]
            lambda {|f|
                paths.each do |p|
                    return true if f=~Regexp.new(p)
                end
                false
            }
        end
    end
end

