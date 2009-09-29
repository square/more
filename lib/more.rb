# Less::More provides methods for parsing LESS files in a rails application to CSS target files.
# 
# When Less::More.parse is called, all files in Less::More.source_path will be parsed using LESS
# and saved as CSS files in Less::More.destination_path. If Less::More.compression is set to true,
# extra line breaks will be removed to compress the CSS files.
#
# By default, Less::More.parse will be called for each request in `development` environment and on
# application initialization in `production` environment.

class Less::More
  DEFAULTS = {
    "production" => {
      :compression        => true,
      :header             => false,
      :page_cache         => true,
      :destination_path   => "stylesheets"
    },
    "development" => {
      :compression        => false,
      :header             => true,
      :page_cache         => true,
      :destination_path   => "stylesheets"
    }
  }
  
  HEADER = %{/*\n\n\n\n\n\tThis file was auto generated by Less (http://lesscss.org). To change the contents of this file, edit %s instead.\n\n\n\n\n*/}
  
  class << self
    attr_writer :compression, :header, :page_cache, :destination_path
    
    # Returns true if compression is enabled. By default, compression is enabled in the production environment
    # and disabled in the development and test environments. This value can be changed using:
    #
    #   Less::More.compression = true
    #
    # You can put this line into config/environments/development.rb to enable compression for the development environments
    def compression?
      get_cvar(:compression)
    end

    # TODO: Use controllers and page cache to generate the files.
    def page_cache?
      (not heroku?) && get_cvar(:page_cache)
    end
    
    # Tells the plugin to prepend HEADER to all generated CSS, informing users
    # opening raw .css files that the file is auto-generated and that the
    # .less file should be edited instead.
    #
    #    Less::More.header = false
    def header
      result = get_cvar(:header)
      get_cvar(:header) ? DEFAULT_HEADER : ""
    end
    
    # The path, or route, where you want your .css files to live.
    def destination_path
      get_cvar(:destination_path)
    end
    
    # Gets user set values or DEFAULTS. User set values gets precedence.
    def get_cvar(cvar)
      instance_variable_get("@#{cvar}") || (DEFAULTS[Rails.env] || DEFAULTS["production"])[cvar]
    end
    
    # Returns true if the app is running on Heroku. When +heroku?+ is true,
    # +page_cache?+ will always be false.
    def heroku?
      !!ENV["HEROKU_ENV"]
    end
    
    # Returns the LESS source path, see `source_path=`
    def source_path
      @source_path || Rails.root.join("app", "stylesheets")
    end
    
    # Sets the source path for LESS files. This directory will be scanned recursively for all *.less files. Files prefixed
    # with an underscore is considered to be partials and are not parsed directly. These files can be included using `@import`
    # statements. *Example partial filename: _form.less*
    #
    # Default value is app/stylesheets
    #
    # Examples:
    #   Less::More.source_path = "/path/to/less/files"
    #   Less::More.source_path = Pathname.new("/other/path")
    def source_path=(path)
      @source_path = Pathname.new(path.to_s)
    end
    
    # Checks if a .less or .lss file exists in Less::More.source_path matching
    # the given parameters.
    #
    #   Less::More.exists?(["screen"])
    #   Less::More.exists?(["subdirectories", "here", "homepage"])
    def exists?(path_as_array)
      return false if path_as_array[-1].starts_with?("_")
      
      pathname = pathname_from_array(path_as_array)
      pathname && pathname.exist?
    end
    
    # Generates the .css from a .less or .lss file in Less::More.source_path matching
    # the given parameters.
    #
    #   Less::More.generate(["screen"])
    #   Less::More.generate(["subdirectories", "here", "homepage"])
    #
    # Returns the CSS as a string.
    def generate(path_as_array)
      source = pathname_from_array(path_as_array)
      engine = File.open(source) {|f| Less::Engine.new(f) }
      css = engine.to_css
      css.delete!("\n") if self.compression?
      css
    end
    
    # Generates all the .css files.
    def generate
      Less::More.all_less_files.each do |path|
        # Get path
        relative_path = path.relative_path_from(Less::More.source_path)
        path_as_array = relative_path.to_s.split(File::SEPARATOR)
        path_as_array[-1] = File.basename(path_as_array[-1], File.extname(path_as_array[-1]))

        # Generate CSS
        css = Less::More.generate(path_as_array)

        # Store CSS
        path_as_array[-1] = path_as_array[-1] + ".css"
        destination = Pathname.new(File.join(Rails.root, "public", Less::More.destination_path)).join(*path_as_array)
        destination.dirname.mkpath

        File.open(destination, "w") {|f|
          f.puts css
        }
      end
    end
    
    # Removes all generated css files.
    def clean
      all_less_files.each do |path|
        relative_path = path.relative_path_from(Less::More.source_path)
        css_path = relative_path.to_s.sub(/le?ss$/, "css")
        css_file = File.join(Rails.root, "public", Less::More.destination_path, css_path)
        File.delete(css_file) if File.file?(css_file)
      end
    end
    
    # Array of Pathname instances for all the less source files.
    def all_less_files
      Dir[Less::More.source_path.join("**", "*.{less,lss}")].map! {|f| Pathname.new(f) }
    end
    
    # Converts ["foo", "bar"] into a `Pathname` based on Less::More.source_path.
    def pathname_from_array(array)
      path_spec = array.dup
      path_spec[-1] = path_spec[-1] + ".{less,lss}"
      Pathname.glob(self.source_path.join(*path_spec))[0]
    end
  end
end