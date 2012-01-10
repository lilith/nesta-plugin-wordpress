module Nesta
  module Plugin
    module Wordpress
      module Helpers
        # If your plugin needs any helper methods, add them here...
      end
    end
  end

  class App
    helpers Nesta::Plugin::Wordpress::Helpers
  end
end
