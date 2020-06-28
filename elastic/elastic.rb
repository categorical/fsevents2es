

module Elastic
    require 'elasticsearch'
    #require_relative '../logging'

    @client=nil

    class<<self
        def connect config
            cnx=config[:cnx]
            hosts=cnx[:hosts].map{|h|
            {host: h[:host],port: h[:port]}}
            @client=Elasticsearch::Client.new(
                hosts: hosts,
                logger: Logging.newlogger.tap{|l| l.level=Logger::INFO},
                log: true)
        end

        def clean olderthandays=10
            n=Config.elastic[:indexname]
            prefix=n.partition('{').first
            tnow=Time.now.to_i
            indices=self.indices.lines.map{|l|
                l.split(/\s+/)[2]
            }
            indices.each{|v|
                next if v.nil?
                next unless v.start_with? prefix
                utcdate=v.match(/(\d{2}\.\d{2}\.\d{4})/)[1]
                if utcdate.nil?
                    next
                end
                begin
                    t=Time.strptime(utcdate<<'UTC','%d.%m.%Y%Z').to_i
                rescue=>e
                    Logging.error "Refuses to die \e[91m#{v}\e[0m: #{e.message}"
                    next
                end
                # Kills if larger than the index's days.
                next if tnow-t<=3600*24*olderthandays.to_i
                
                Logging.info "Sending \e[91m#{v}\e[0m to oblivion."
                deleteindex v
            }
        end

        def indices
            @client.cat.indices
        end

        def count
            @client.count
        end

        def bulkindex docs,chunksize=10
            debug=Config.instance_variable_get :@debug
            send=lambda do |msgs|
                unless debug
                    @client.bulk body: msgs
                    return
                end
                Logging.debug "Messages: #{msgs}"
            end

            c=0
            msgs=[]
            docs.each do |doc|
                msgs<<{index:{_index: indexname,_type: doc[:_type]}}
                msgs<<doc.tap{|x| x.delete(:_type)}
                c+=1
                if c<chunksize
                    next
                end
                send.call msgs
                msgs=[]
                c=0
            end
            send.call msgs
        end

        def indexname
            n=Config.elastic[:indexname]
            utcdate=Time.now.utc.strftime '%d.%m.%Y'
            n.sub '{utcdate}',utcdate
        end

        def ensuretemplate
            begin
                # Elasticsearch deprecated `string` type in favour of `text` and `keyword` type.
                # `string` type with index option `not_analyzed` causes parse error when indexing documents.
                t=JSON.parse(File.read(fileabspath 'indextemplate.json',__FILE__))
                t.merge!({
                    'template'=>Config.elastic[:indexname].sub('{utcdate}','*')
                })
                @client.indices.put_template(
                    name: 'default',
                    body: t)
            rescue=>e
                Logging.error e
            end
        end

        def deleteindex name
            begin
                @client.indices.delete index: name
            rescue=>e
                Logging.error e
            end
        end
        def createindex name
            begin
                @client.indices.create index: name
            rescue=>e
                Logging.error e
            end
        end
    end
end




