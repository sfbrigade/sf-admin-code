require 'rubygems'
require 'nokogiri'
require 'json'
require 'watir-webdriver'

# define a utility method we'll need later
def collect_between(first, last)
  	first == last ? [first] : [first, *collect_between(first.next, last)]
end

# also define a way to search html text for the section class definition
def is_a_section(str)
    (str =~ /class="Section"/i) != nil
end

# also define a way to search html text for the footer div containing disclaimer
def is_footer(str)
    (str =~ /American Legal Publishing Corporation provides these documents for informational purposes only./i) != nil
end

# methods for database access
def insert_chapter(title)

#	my = Mysql::new("host", "user", "passwd", "db")
	con = Mysql::new('127.0.0.1', 'root', 'root', 'sf_admin_code')
	
	pst = con.prepare "INSERT INTO Chapter(title) VALUES(?)"
    pst.execute title
    con.close
	
	return con.insert_id()
end

def insert_article(title)

	con = Mysql.new '127.0.0.1', 'root', 'root', 'sf_admin_code'
	pst = con.prepare "INSERT INTO Article(title) VALUES(?)"
    pst.execute title
    con.close

	return con.insert_id()
end

def insert_section(title,text)

	con = Mysql.new '127.0.0.1', 'root', 'root', 'sf_admin_code'
	pst = con.prepare "INSERT INTO Section(title,text) VALUES(?,?)"
    pst.execute title,text
    con.close
    
    return con.insert_id()
end

def link_chapter_article(chapter_id,article_id)

	con = Mysql.new '127.0.0.1', 'root', 'root', 'sf_admin_code'
	pst = con.prepare "INSERT INTO ChapterArticle(chapter_id,article_id) VALUES(?,?)"
    pst.execute chapter_id,article_id
    con.close

end

def link_chapter_section(chapter_id,section_id)

	con = Mysql.new '127.0.0.1', 'root', 'root', 'sf_admin_code'
	pst = con.prepare "INSERT INTO ChapterSection(chapter_id,section_id) VALUES(?,?)"
    pst.execute chapter_id,section_id
    con.close

end

def link_article_section(article_id,section_id)

	con = Mysql.new '127.0.0.1', 'root', 'root', 'sf_admin_code'
	pst = con.prepare "INSERT INTO ArticleSection(article_id,section_id) VALUES(?,?)"
    pst.execute article_id,section_id
    con.close

end

browser = Watir::Browser.new
browser.goto 'http://www.amlegal.com/nxt/gateway.dll?f=templates&fn=default.htm&vid=amlegal:sanfrancisco_ca'

frame = Nokogiri::HTML(browser.frame(:name,"contents").html)

first_level_container = frame.css("body")[0].css('div#California_c')[0].css('div')[3]

an_img = first_level_container.css('img')[0]

browser.frame(:name,"contents").element(css: an_img.css_path).click

puts "waiting 6 seconds for operation..."
sleep(6)
puts "done waiting"

# update after pressing the button (takes some time to load--may need to lengthen)
frame = Nokogiri::HTML(browser.frame(:name,"contents").html)
first_level_container = frame.css("body")[0].css('div#California_c')[0].css('div')[3]

morenode_img = first_level_container.css("[ct='application/morenode']")[0].css('img')[0]

browser.frame(:name,"contents").element(css: morenode_img.css_path).click

puts "waiting 4 seconds for operation..."
sleep(4)
puts "done waiting"

# update again after pressing more button
frame = Nokogiri::HTML(browser.frame(:name,"contents").html)
first_level_container = frame.css("body")[0].css('div#California_c')[0].css('div')[3]

chapters = first_level_container.css("[class='treenode']")

puts "number of elements:"
puts chapters.length

# initialize the sections and titles arrays
sections_array = Array.new()
titles_array = Array.new()

chapters.each_with_index do |chapter,i|
 	# within each Chapter, except the first and last which are weird...
 	if i == 0 || i == chapters.length - 1
 		puts "skipping non-numbered chapters"
 	else
  
		# find the link that needs to be clicked
		chapter_link = chapter.css("[class='nodetext']")[0]
  
		# click on that element
		browser.frame(:name,"contents").element(css: chapter_link.css_path).click
  
		#wait 2 seconds
		puts "waiting 2 seconds for operation..."
		sleep(2)
		puts "done waiting"

		#scoot over to the main window
		doc_body = Nokogiri::HTML(browser.frame(:name,"main").frame(:name,"docbody").html)
  
		# grab the chapter's title-- the first one is weird but the rest are same
  		chapter_title = doc_body.css("[class='Chapter']")[0].css('span')[0].text
	
		# originally the index started at ': ' but now ':'
	
		# get the index and text title separated
		chapter_index = chapter_title[(chapter_title.index('R')+2)..(chapter_title.index(':')-1)]
		chapter_name = chapter_title[(chapter_title.index(':')+2)..-1]
		
		# add the index and text to an array
 		chapter_array = Array.new()
		chapter_array.push(chapter_index)
		chapter_array.push(chapter_name)
		
		# add the array to the titles_array
		titles_array.push(chapter_array)
  
		# grab any articles in it
		articles = doc_body.css("[class='Article']") 
	
		# we may not need the histories? trying with disclaimer div
		footers  = doc_body.search "[text()*='American Legal Publishing Corporation provides these documents for informational purposes only.']"
		footer   = footers.last
  
		articles.each_with_index do |article,j|
 			# for each article...
		  	
		  	# grab histories too, for now
		  	histories = article.css("[class='History']")
		  
		  	# isolate the html chunk associated with this article (last is tricky)
		  	if j < articles.length - 1
				paragraphs = collect_between(article,articles[j+1])
		  	else
	 			paragraphs = collect_between(article,footer)
		  	end

		  	# use our custom method to get the elements that are sections
  		  	sections1 = paragraphs.select { |p| is_a_section(p.to_s)}
  
  		  	sections1.each_with_index do |section1,k|
  		    	# for each section:
  
			  	# grab and add the section's title
			  	# some of theme are in different formats!
			  	# most are in a span, but a few are just in the h5
			  	
			  	section_title = section1.text.gsub("\n"," ")
  
			  	# grab the text inside the section. last one is tricky!!
			  	if k < sections1.length - 1
				  	paragraphs1 = collect_between(section1,sections1[k+1])
		  	  	elsif j < articles.length - 1
		  	  		#replacing histories.last with footer
	              	paragraphs1 = collect_between(section1,histories.last)
	            else
	              	paragraphs1 = collect_between(section1,footer)
			  	end
		  
			  	section_text1 = ""
		  
			  	paragraphs1.each_with_index do |paragraph1,l|
			  		if l != 0 && l < paragraphs1.length - 1 #&& k < sections1.length - 1
				  		section_text1 += paragraph1
			  	#	elsif l != 0 && k == sections1.length - 1
			  	#		section_text1 += paragraph1
			  		end
			  	end
		  
		  		# parse section_title
		  		section_title_a = section_title[(section_title.index(' ')+1)..-1]
		  		section_title_index = section_title_a[0...section_title_a.index(' ')]
		  		section_title_text = section_title_a[(section_title_a.index(' ')+1)..-1]
		  		
		  		# add section title to new array
		  		section_array = Array.new()
		  		section_array.push(section_title_index)
		  		section_array.push(section_title_text)
		  		sections_array.push(section_array)
		  		
		  		# TODO: create a file for this section
  
  	  	end
  	end
  
  	# at chapter level, if no articles then grab any sections in it
  	if articles.length == 0
  
  	  	sections2 = doc_body.css("[class='Section']") 	 
  
	  	sections2.each_with_index do |section2,k|
  		  	# for each section:
  
		  	# grab and add the section's title
		  	section_title2 = section2.css('span')[0].text
  
		  	# grab the text inside the section. last one is tricky
		  	if k < sections2.length - 1
			  	paragraphs = collect_between(section2,sections2[k+1])
		  	else
	 		  	paragraphs = collect_between(section2,footer)
	 	#	else
	 			# TODO: need case for 29A, where the last paragraph DOESN't have history
	 			# last before div?????
	 	#		paragraphs = collect_between(section2,histories.last)
		  	end
		  
		  	section_text2 = ""
		  
		  	paragraphs.each_with_index do |paragraph,l|
		  	
		  		if l != 0 && l < paragraphs.length - 1 #&& k < sections2.length - 1
			  		section_text2 += paragraph
		  #		elsif l != 0 && k == sections2.length - 1
		  #			section_text2 += paragraph
		  		end
			end
		  
		  	# parse section_title
		  	section_title_a = section_title2[(section_title2.index(' ')+1)..-1]
		  	section_title_index = section_title_a[0...section_title_a.index(' ')]
		  	section_title_text = section_title_a[(section_title_a.index(' ')+1)..-1]
		  		
		  	# add section title to new array
		  	section_array = Array.new()
		  	section_array.push(section_title_index)
		  	section_array.push(section_title_text)
		  	sections_array.push(section_array)
		  	
		  	# create a JSON Object for this section
		  	section_object = Hash.new()
		  	
		  	# text
		  	section_object.merge!(:text => section_text2)
		  	
		  	# credits (tag is history but it seems more credit like?)
		  	
		  	# division (identifier and text). use article
		  	
		  	# chapter (identifier and text). use chapter
		  	
		  	# heading
		  	section_heading = Hash.new()
		  	section_heading.merge!(:title => section_title_index[0...section_title_index.index('.')])
		  	section_heading.merge!(:chaptersection => section_title_index[(section_title_index.index('.')+1)..-1])
		  	section_heading.merge!(:identifier => section_title_index)
		  	section_heading.merge!(:catch_text => section_title_text)
		  	section_object.merge!(:heading => section_heading)
		  	
		  	# create a file for this section and put in json with title_index
		  	File.open(section_title_index + ".json","w") do |f|

				f.write(section_object.to_json)

			end
	  
	  	end

  	end
    end
end

File.open("sids.json","w") do |f|

	f.write(sections_array.to_json)

end

# add sids and titles to new index object
index_object = Hash.new()

index_object.merge!(:sections => sections_array)
index_object.merge!(:titles => titles_array)


File.open("index.json","w") do |f|

	f.write(index_object.to_json)

end

# TODO: extra. handle the first and last chapters. they are not real chapters so their formatting is funky

#celebrate good times
#come on