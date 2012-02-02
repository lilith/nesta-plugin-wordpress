# nesta-plugin-wordpress

An import script and set of routes to help migrate from Wordpress with minimal hassle.

The import script follows redirects, builds a set of compatibility paths for each page, and downloads attachments. It expects everything to be on the same domain, and cross-domain redirects will confuse it. 

### Routes

* /wp-content/\* -> /attachments/wp-content/\*
* /feed/ -> /articles.xml
* /comments/feed/ -> http://#{short_name}.disqus.com/latest.rss

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
8. In Disqus, go to Tools>Migrate Threads> Redirect Crawler. Start the redirect crawler; this should consolidate all your comments and associate them with the 'primary' version of each article. **Remember**: You'll need to do this a second time after you've pointed the domain to the new Nesta server.

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

	Aliases: /image-resizer-installation/ /?page_id=91 /?p=91
	Atom ID: http://66.29.219.39/?page_id=91
	Post ID: 91
	Author: Nathanael Jones
	wp_date: 2010-11-11 19:44:48 -0500
	wp_template: default
	wp_status: private
	Flags: hidden
	Summary: This is the article summary
	Categories: image-resizing, installation
	Tags: image-resizing, image-resizer

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
* Wordpress metadata "url" (user-defined "url" field)

The resulting set is made domain-relative and cleansed of duplicates. 

This is how the `Aliases: /?p=27 /1204_My_Article /2009/11/12/my-article` metadata tag is determined. 

## Part 3. Executing the script

Double-check you have everything committed before starting, so you can see what has been changed. Files can get overwritten.

#### This does a fast 'offline import'. Use this first to verify there are no errors

	bundle exec wordpress-to-nesta -f -a

#### Use this to perform a full import. Downloads all attachments and checks for 301/302 redirects to determine what aliases need to be specified for each page

 	bundle exec wordpress-to-nesta

#### If you want to restore the "Author", "wp\_date", "wp\_template", and "wp\_status" metadata fields
 	bundle exec wordpress-to-nesta -d none

#### If you for, some reason, want to delete all the metadata during conversion, run
	bundle exec wordpress-to-nesta -d "Author","wp_status","Flags","wp_date","wp_template","Aliases","Atom ID","Post ID","Status","Categories","Tags","Summary","Date"

#### If your XML files isn't named wordpress.xml, you can specify it
	bundle exec wordpress-to-nesta -c wordpress-other-file.xml

Once the conversion script has finished, make sure you review the log for errors. 

## Part 4. Post-conversion steps

If you're using nesta-plugin-wordpress and nesta-plugin-aliases

1. Manually update menu.txt
2. Make sure disqus\_short\_name is set in config.yml
3. Forget about redirecting comment RSS feeds from individual pages... or figure out how to calculate them. Disqus seems to use the normalized title of the page, which seems...fragile. Ex. http://shortname.disqus.com/normalized-title/latest.rss

If you're not using those plugins... you'll still need the custom version of nesta and nesta-plugin-simplicity, and you'll have to manually:

1. Set up generic rewrites 
* /wp-content/ to /attachments/wp-content/
* /feed/ to /articles.xml
2. Add comment-specific redirects
* /comments/feed/ to http://intensedebate.com/allBlogCommentsRSS/37301  (ID of blog with intensedebate) or http://{disqus_short_name}.disqus.com/latest.rss
* /id/article/feed/ to http://intensedebate.com/postRSS/104986059  (ID of post with intensedebate) or ???
3. URL redirect from each space-delimited value in 'Aliases' of each page metadata to the actual page path (or use nesta-plugin-aliases)


### We didn't make views/pages for tags and categories!

* Tags and categories from Wordpress are imported as-is. Maybe these need to be combined or something, haven't figured out how exactly I'm mapping them to Nesta's design.
* No views for /tag/{tag}/
* No views for /category/{category}/
* No views for /category/{category}/{child-category}/

### IntenseDebate vs. Disqus

As a long-time user of IntenseDebate, I originally wanted to port my IntenseDebate comments over directly. However, after using Disqus for a bit, I realized it was a much nicer service. And it imports directly from both IntenseDebate and Wordpress. 

If you want to stay with IntenseDebate, you'll have to do some coding for it

1. Configure IntenseDebate to use the page.metadata["Post ID"] for the idcomments_post_id value (if present) (Requires view editing)

	<script>
	var idcomments_acct = ‘YOUR ACCT ID’;
	var idcomments_post_id; //<- this is where you use "Post ID"
	var idcomments_post_url;
	</script>
	<script type=”text/javascript” src=”http://www.intensedebate.com/js/genericLinkWrapperV2.js”></script>

2. Write code against the IntenseDebate API to fix your comment feeds

* /comments/feed/ to http://intensedebate.com/allBlogCommentsRSS/37301  (ID of blog with intensedebate)
* /id/article/feed/ to http://intensedebate.com/postRSS/104986059  (ID of post with intensedebate)

