


module Logging
    class<<self
        def logger
            @l||=lambda do
                require 'logger'
                l=Logger.new(STDOUT)
                l.level=Logger::DEBUG
                l.formatter=proc do |s,d,p,m|
                    "#{d.strftime '%Y-%m-%d %H:%M:%S'} #{s}: #{m}\n"
                end
                l
            end.call
        end
        def newlogger
            logger.clone
        end
        def info message
            logger.info message
        end
        def error message
            logger.error message
        end
        def debug message
            logger.debug message
        end
    end
end




