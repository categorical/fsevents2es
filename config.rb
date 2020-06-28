

module Config
    
    class<<self
        def loadconfig
            @config||=JSON.parse(File.read(fileabspath 'config.json'),symbolize_names:true)
        end
        def elastic
            loadconfig[:elastic]
        end
        def fsevents
            loadconfig[:fsevents]
        end
    end
end
