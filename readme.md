# nesta-plugin-wordpress

An import script and set of routes to help migrate from Wordpress with minimal hassle.

The import script follows redirects, builds a set of compatibility paths for each page, and downloads attachments.

The goal is to leave no broken links. 

### Routes

* /wp-content/\* -> /attachments/wp-content/\*
* /feed/ -> /articles.xml

## Migration guide

### Part 1. Preparing for the conversion

1. Make sure you have a new or existing Nesta site, with all new and modified files committed to Git.  We'll call this 'your site' from now on. And we're assuming all commands specified here are executed from the root of your site. We're also expecting all files in UTF-8 form.
2. Edit your gemfile to use my branch of Nesta and the following 4 plugins. Strictly speaking, you can omit 'nesta-plugin-tags' if you don't want tag functionality.
	gem 'nesta', :git => "git://github.com/nathanaeljones/nesta.git"
	gem 'nesta-plugin-aliases', :git => "git://github.com/nathanaeljones/nesta-plugin-aliases.git"
	gem 'nesta-plugin-simplicity', :git => "git://github.com/nathanaeljones/nesta-plugin-simplicity.git"
	gem 'nesta-plugin-wordpress', :git => "git://github.com/nathanaeljones/nesta-plugin-wordpress.git"
	gem 'nesta-plugin-tags', :git => "git://github.com/nathanaeljones/nesta-plugin-tags.git"
3. Run `bundle install`
4. Make sure your Wordpress site is still running and available at its original location. It needs to be online for the redirect tracker and attachment downloader to work.
5. Go to Tools-> Export on your Wordpress site. Choose "All content", and save the exported file as "wordpress.xml" in the root of your new site.
6. In your Disqus account, make a site matching your current domain. Make sure the Website URL matches the primary website URL of your site. 
7. In Disqus, go to Tools>Import and import the wordpress.xml file. Wait till it's finished.
8. In Disqus, go to Tools>Migrate Threads> Redirect Crawler. Start the redirect crawler; this should consolidate all your comments and associate them with the 'primary' version of each article. 

## Part 2. The Theory of conversion

### Content conversion rules

* Page and Post content will be converted from HTML to XHTML. The conversion is done with Hpricot followed by Nokogiri. Hpricot has the best element closure detection, Nokogiri enforces proper entity encoding. This mimics browser 'autocorrection' very well, and shouldn't corrupt your content. 
* The title is placed at the beginning of the content between &lt;h1>&lt;/h1> tags. 

### Wordpress metadata conversion rules

* Metadata pairs with null or empty values are discarded.
* Metadata pairs with keys starting in "\_" are discarded. (With the exception of \_wp\_page\_template, which becomes wp\_template in the page header)
* User-defined fields are added to the end of the file as XML comments.
* Author IDs are converted to Author Display Names
* If available, the GMT post date is used for the Date: field instead of the time-zone specific value. The Date: field is omitted for 'Page' items.
* Password-protected pages/posts will be given `Status: protected` and `Flags: hidden`, but the password will not be copied.
* The following data is dropped: Sticky post flags, comment status, menu order, post parents, and ping status values.

### Generated metadata example

	Aliases: /?p=27 /2009/11/27/my-article/
	Atom ID: http://66.29.219.39/?p=125 (Whatever was used in the orginal RSS feed)
	Post ID: 27
	Author: Nathanael Jones
	wp\_date: 
	 {
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


### Post naming rules

* Public 'Posts' will be placed in /content/pages/blog/YYYY/post-title-sanitized.htmf
* Non-public 'Posts' will be placed in /drafts/post-title-sanitized.htmf and hidden with `Flags: hidden`

### Page naming rules

* All 'Pages' with an assigned URL will be placed in a matching directory strucutre. I.e. /contact/donate will become /contact/donate.htmf
* If a Page doesn't have an assigned URL, it will be dumped in /drafts/
* If a Page is hidden, protected, etc, it will be hidden with `Flags: hidden`
* index.htmf files are not generated for parent pages. Instead, you'll get 'name.htmf' and folder 'name' in the same directory.

### Attachment downloading rules

* Attachments will go into /attachments/wp-content/... They will keep the same directory structure and file name, except for `/attachments/` being prepended.
* Attachments will have a modified date matching their original Upload datestamp. 
* Attachments will be downloaded from the live site, following any redirections issued by the current server.

### Alias (301 redirect) generation rules

Aliases for each post and page are generated by taking the following URLs, requesting them, then collecting a list of all URLs they are redirected through. 

Wordpress does not always store the 'pretty url' in the database, but generates it dynamically. Often, the only way to get the 'official' url for a page is to execute the HTTP request.

* Wordpress Link (official URL for page or psot)
* Wordpress Guid (GUID Permalink)
* Wordpress Post ID (in the form /?p=[post id])
* Wordpress metadata "url" (user-defined "url" flag)

The resulting set is made domain-relative and cleansed of duplicates. 

This is how the `Aliases: /?p=27 /1204_My_Article /2009/11/12/my-article` metadata tag is determined. 

## Part 3. Executing the script

Double-check you have everything committed before starting, so you can see what has been changed. Files can get overwritten.



## Part 4. Post-conversion steps

1. Set up generic rewrites (already done if you're using nesta-plugin-wordpress)
* /wp-content/ to /attachments/wp-content/
* /feed/ to /articles.xml
2. Add comment-specific redirects
* /comments/feed/ to http://intensedebate.com/allBlogCommentsRSS/37301  (ID of blog with intensedebate)
* /id/article/feed/ to http://intensedebate.com/postRSS/104986059  (ID of post with intensedebate)
3. URL redirect from each space-delimited value in 'Aliases' of each page metadata to the actual page path (or use nesta-plugin-aliases)
4. Manually update menu.txt

### We didn't make pages for tags and categories

* Tags and categories from Wordpress are imported as-is. Maybe these need to be combined or something, haven't figured out how exactly I'm mapping them to Nesta's design.
* No views for /tag/{tag}/
* No views for /category/{category}/
* No views for /category/{category}/{child-category}/



### IntenseDebate vs. Disqus

As a long-time user of IntenseDebate, I originally wanted to port my IntenseDebate comments over directly. However, after using Disqus for a bit, I realized it was a much nicer service. And it imports directly from both IntenseDebate and Wordpress. 

So




### IntenseDebate notes

For those who want to bring IntenseDebate comments over directly to their new Nesta site, I'm listing a few comments.

#7.  Configure IntenseDebate to use the page.metadata["Post ID"] for the idcomments_post_id value (if present) (Requires view editin)

#<script>
#var idcomments_acct = ‘YOUR ACCT ID’;
#var idcomments_post_id; //<- this is where you use "Post ID"
#var idcomments_post_url;
#</script>
#<script type=”text/javascript” src=”http://www.intensedebate.com/js/genericLinkWrapperV2.js”></script>
