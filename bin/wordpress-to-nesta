#!/usr/bin/env ruby
# coding: utf-8


# This does a fast 'offline import'. Use this first to verify there are no errors
# ruby -r './import.rb' -e 'Nesta::WordpressImport.process(true)'

# Use this to perform a full import. Downloads all attachments and checks for 301/302 redirects to determine what aliases need to be specified for each page
# ruby -r './import.rb' -e 'Nesta::WordpressImport.process()'

# If you want to add the "Author", "wp_date", or "wp_template" metadata fields, pass in an empty array to the drop_metadata parameter
# ruby -r './import.rb' -e 'Nesta::WordpressImport.process(true, "wordpress.xml",[])'

#  Or, drop everything
# ruby -r './import.rb' -e 'Nesta::WordpressImport.process(true, "wordpress.xml",["Author","wp_status","Flags","wp_date","wp_template", "Aliases", "Atom ID", "Post ID", "Status", "Categories", "Tags"])'



require 'rubygems'
require 'net/http'
require 'uri'
require 'hpricot'
require 'fileutils'
require 'yaml'
require 'time'
require 'nokogiri'
require 'optparse'

module Nesta
  module Plugins
    module Wordpress
      # This importer takes a wordpress.xml file, which can be exported from your
      # wordpress.com blog (/wp-admin/export.php).
      class Importer
    
        def self.main
      
          offline = false
          root = Dir.pwd
          filename = "wordpress.xml"
          drop_metadata=["Author","wp_date","wp_template"]
          
          options = {}
          OptionParser.new do |opts|
            opts.banner = "Usage: bundle exec nesta-to-wordpress [options]"
            
            opts.separator ""
            opts.separator "Options:"
            
            opts.on("-c", "--convert wordpress.xml",
                          "Generate the site structure from the specified Wordpress EXR (XML) file. (Defaults to wordpress.xml)") do |fname|
              filename = fname
            end

            opts.on("-o", "--offline", "Run offline - do not track redirects or download attachments. Doesn't produce accurate 301 redirects.") do |v|
              offline = v
            end
            
            opts.on("--drop-metadata \"Author\",\"wp_date\",\"wp_template\"", Array, "Drop the specified metadata items from the all files during conversion.") do |list|
              drop_metadata = list
            end
            
            opts.on_tail("-h", "--help", "Show this message") do
              puts opts
              exit
            end
                  
          end.parse!

          new Importer.import(offline,root,filename,drop_metadata);
        end
    
        # Returns a list of URLs (including the one passed in) based on HTTP redirects that occured. 
        def get_redirections(url, limit = 10)
          return [] if limit == 0 #Prevent infinite loops
      
          url_list = [url]
          uri = URI.parse(url)
          Net::HTTP.start(uri.host,uri.port){ |http| 
            http.request_get(strip_domain(url)){ |res| 
              case res
              when Net::HTTPSuccess
                return url_list #We are done!
              when Net::HTTPRedirection
                return  url_list.concat(get_redirections(res.header['location'] , limit - 1)).uniq
              else
                return url_list
              end
            }
          }
        rescue
          puts "Failed to reach #{url}, #{$!.to_s}"
          return [url]
        end
    
    
        # Downloads a file, correctly following any redirections required. 
        def download_file(url,dest_path,  limit = 10)
          raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      
          puts "Downloading #{url} to #{make_relative(dest_path)}"
          uri = URI.parse(url)
          Net::HTTP.start(uri.host,uri.port){ |http| 
            http.request_get(strip_domain(url)){ |res| 
              case res
              when Net::HTTPSuccess
                #On success, buffer to disk
                File.open(dest_path,'w'){ |f|
                  res.read_body{ |seg|
                    f << seg
                    #hack -- adjust to suit:
                    sleep 0.005 
                  }
                }
                return true
                #Follow redirects
              when Net::HTTPRedirection
                return download_file(res.header['location'] ,dest_path, limit - 1)
              else
                response.error!
                return false
              end
            }
          }
        rescue
          puts "Failed to reach #{url}, #{$!.to_s}"
        end
    
        def download(url, dest_path, upload_date)
          return false if File.exists?(dest_path)
          FileUtils.mkdir_p(File.dirname(dest_path)) if not Dir.exists?(File.dirname(dest_path)) 
        
          if download_file(url,dest_path)
            File.utime(upload_date,upload_date,dest_path)
          end
      
          return true
        end
    
        def make_relative(path)
          here = File.expand_path('.', ::File.dirname(__FILE__))
          return (path.start_with?(here)) ? path[here.length..-1] : path
        end
    
        def strip_domain(url)
          uri = URI.parse(url)
          return uri.path + ((uri.query.nil? || uri.query.empty?) ? "" : "?#{uri.query}")
        end
    
        def tidy_html(html)
          engine = "nokricot"
          require engine if not engine == "nokricot"
          case engine
          when "nokricot"
            require 'nokogiri'
            require 'hpricot'
             return Nokogiri::XML::DocumentFragment.parse(Hpricot(html).to_s).to_s
          when "hpricot"
            return Hpricot(html).to_s
          when "nokogiri"
             return Nokogiri::XML::DocumentFragment.parse(html).to_s
          when "tidy"
            tidy = Tidy.open({:show_warnings => true, :show_body_only => true}) do |tidy|
              return tidy.clean(html)
            end
          end
        end
    
        def get_domain(url)
          uri = URI.parse(url)
          port = uri.port.nil? ? "" : ":#{uri.port}"
          return "http://#{uri.host}#{port}"
        end
    
        def get_alternate_urls(item, metadata, offline=false)
          #Build an array of the 4 data sources: wp:post_id, link, guid, and metadata 'url'
          post_id = item.at('wp:post_id').inner_text
          urls = [item.at('link').inner_text,
                  item.at('guid').inner_text,
                  get_domain(item.at('link').inner_text) + "/?p=#{post_id}"]
          meta_url = metadata["url"]
          urls.push('/' + meta_url.gsub(/^\//,"")) if not meta_url.nil?
          #Cleanse array
          urls = urls.uniq.reject{|i| i.nil? || i.empty?}
          #Use HTTP requests to capture any redirections.
          short_urls = []
          urls.each{|v| 
            if offline
              short_urls.push(strip_domain(v))
            else
              get_redirections(v).each{|url|
                short_urls.push(strip_domain(url))
              }
            end
          }
          #strip domains, duplicates, and remove empty values
          return short_urls.uniq.reject{|i| i.nil? || i.empty?}

        end


        def import(offline=false, root=::File.dirname(__FILE__), filename = "wordpress.xml",  drop_metadata=["Author","wp_date","wp_template"])
          
          
          import_count = Hash.new(0)
          doc = Hpricot::XML(File.read(filename))
      
          ## Where to store the attachements. We'll need a URL rewriting rule to change '/wp-content' -> '/attachments/wp-content'
          attachment_dir = File.expand_path('content/attachments', root)
          # Where to store posts and pages
          content_dir = File.expand_path('content/pages', root)
      
          #A hash to detect duplicate URLs in the XML
          items_by_urls = {}
      
      
          authors = {}
          #Build hash of login->display name for authors
          (doc/:channel).first.get_elements_by_tag_name('wp:author').each do |author|
            author_login = author.at('wp:author_login').inner_text.strip
            author_name = author.at('wp:author_display_name').inner_text.strip
            authors[author_login] = author_name
            puts "Author #{author_login} will be mapped to #{author_name}"
          end
      

          (doc/:channel/:item).each do |item|
            #Get the item title
            title = item.at(:title).inner_text.strip
        
            #Get post_id
            post_id = item.at('wp:post_id').inner_text
        
            puts "Importing  #{post_id} - #{title}"
        
            #Item type: post, page, or attachment
            type = item.at('wp:post_type').inner_text
            #GMT posted date - always available for attachements, but not always for posts/pages that have never been published.
            #Fall back to post_date when we get an ArgumentError - will be off by an unknown timezone, but date should be correct.
            post_date_gmt = Time.parse(item.at('wp:post_date_gmt').inner_text) rescue Time.parse(item.at('wp:post_date').inner_text)

            #Download attachments unless they already exist
            if type == "attachment"
              a_url = item.at('wp:attachment_url').inner_text
              if offline
                puts "(Offline) Skipping #{a_url}"
              else
                download(a_url, attachment_dir + strip_domain(a_url), post_date_gmt)
              end
            elsif
        
              #Parse metadata into a hash
              metas = Hash[item.search("wp:postmeta").map{ |meta| [meta.at('wp:meta_key').inner_text, meta.at('wp:meta_value').inner_text]}]
        
              #The template used by wordpress. Can be used to allow regex migrations to Nesta templates
              wp_template = metas["_wp_page_template"]
        
              #Discard all meta keys starting with '_', and all empty meta values
              metas.reject!{|k,v|k[0] == "_" || v.empty?}

              #Parse tags and categories
              tags = (item/:category).reject{|c| c.attributes['domain'] != 'post_tag'}.map{|c| c.attributes['nicename']}.uniq
              categories = (item/:category).reject{|c| c.attributes['domain'] != 'category'}.map{|c| c.attributes['nicename']}.reject{|c| c == 'uncategorized'}.uniq

              #Calculate the status of the page or post: publish, draft, pending, private, or protected
              status = item.at('wp:status').inner_text
              status = "protected" if not item.at('wp:post_password').inner_text.empty?
              is_public = status == "publish"

              #Get the slug, fallback to normalized title, then fallback to post ID.
              post_name = item.at('wp:post_name').inner_text
              post_name = title.downcase.split.join('-') if post_name.empty?
              post_name = post_id if post_name.empty?
              #Sanitize
              post_name = post_name.gsub(/[-]?[^A-Za-z0-9-]+[-]?/,"-").gsub(/^[-]+/,"").gsub(/[-]+$/,"")
              puts "\n\n\n#{post_name}\n\n\n" if post_name.include?("/") 

              #Calculate the location for the .htmf file
              link_uri = URI.parse(item.at('link').inner_text)
          
              old_path_query = strip_domain(item.at('link').inner_text)
        
              #The path (no domain, no port, no querystring) of the item's active URL. No trailing or leading slashes
              new_path = link_uri.path.gsub(/^\//,"").gsub(/\/$/,"")

              if type == "page"
                #Un-named pages go in the drafts folder, regardless of their status.
                #Named, but status=draft, private, protected, pending posts simply get flagged, not renamed
                if new_path.empty?;
                  new_path = "drafts/#{post_name}"
                elsif !is_public
                  puts "Page #{new_path} has a status of #{status}. Please review file."
                end 
              elsif type == "post"
                #Only public articles go into /blog/ 
                if is_public
                  new_path = "blog/#{post_date_gmt.year}/#{post_name}"
                  puts "Article #{old_path_query} was placed at #{new_path}"
                else
                  new_path = "drafts/#{post_name}"
                  puts "(#{status} article #{old_path_query} was placed at #{new_path}"
                end
              end
        
              short_new_path = new_path
        
              #Add dir and extension
              new_path = "#{content_dir}/#{new_path}.htmf"
        
              #Acquire a list of all the URLs that may have been used to link to this post or page, so we can add redirects later
              #Exclude any duplicates with previous files - first come, first serve.
              alternate_urls = get_alternate_urls(item,metas, offline).reject{|u|
                if items_by_urls.has_key?(u)
                  puts "Duplicate URL '#{u}' used by more than one item - will not be added"
                  puts "Current:  #{short_new_path},   First item: #{items_by_urls[u]}"
                  puts ""
                  true
                else
                  items_by_urls[u] = short_new_path
                  false
                end
              }

              #Convert post_id to an int unless its a string (to avoid the quotes)
              post_id = post_id.to_i if post_id.match(/^\d+$/)
          
              #Generate metadata table for new file
              metadata = {
                        "Aliases" => alternate_urls * " ",
                        "Atom ID" => item.at('guid').inner_text.strip,
                        "Post ID" => post_id,
                        "Author" => authors[item.at('dc:creator').inner_text.strip],
                        "wp_date" => post_date_gmt.to_s,
                        "wp_template" => wp_template,                    
                        "Summary" => item.at('excerpt:encoded').inner_text.strip,
                        "wp_status" => status == "publish" ? "" : status,
                        "Flags" => status == "publish" ? "hidden" : "",
                        "Categories" => categories * ", ",
                        "Tags" => tags * ", "
                        }
              #Dont' add any values that are empty
              metadata.reject!{|k,v| v.nil? or  v.to_s.empty?}
        
              #Articles/posts (not pages) get a 'Date' value - this is what Nesta uses to differentiate them
              metadata["Date"] = post_date_gmt.strftime("%b %e %Y").gsub("  "," ") if type == "post"
 
              #Make sure metadata uses string keys
              #metadata = metadata.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}
          
              #drop the excluded metadata
              metadata.reject!{|k,v| drop_metadata.include?(k)}
          
              #Create file
              FileUtils.mkdir_p File.dirname(new_path) if not Dir.exists?(File.dirname(new_path)) 
              File.open(new_path, "w") do |f|
                f.puts metadata.to_yaml.gsub(/^---\s*/,"") #Strip leading dashes
                f.puts "\n<h1>#{title}</h1>\n\n"
                f.puts tidy_html(item.at('content:encoded').inner_text)
                f.puts "\n"
                metas.each { |key, value|
                  f.puts "<!--#{key.gsub(/-/,"&#45;")}: #{value.gsub(/-/,"&#45;")}-->\n"
                }
              end
            end
            import_count[type] += 1
          end

          import_count.each do |key, value|
            puts "Imported #{value} #{key}s"
          end
        end
      end
    end
  end
end
Nesta::Plugins::Wordpress::Importer.main

