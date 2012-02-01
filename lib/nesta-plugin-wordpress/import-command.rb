module Nesta
  module Commands
    module Wordpress
      class Import
        include Command
        
        def initialize(*args)
          @args = args
        end
        
        def execute()
          puts @args
        end
      end
    end
  end
end