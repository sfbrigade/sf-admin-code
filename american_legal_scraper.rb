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

browser = Watir::Browser.new
browser.goto 'http://www.amlegal.com/nxt/gateway.dll?f=templates&fn=default.htm&vid=amlegal:sanfrancisco_ca'

frame = Nokogiri::HTML(browser.frame(:name,"contents").html)

first_level_container = frame.css("body")[0].css('div#California_c')[0].css('div')[3]

an_img = first_level_container.css('img')[0]

browser.frame(:name,"contents").element(css: an_img.css_path).click

puts "waiting 7 seconds for operation..."
sleep(7)
puts "done waiting"

# update after pressing the button (takes some time to load--may need to lengthen)
frame = Nokogiri::HTML(browser.frame(:name,"contents").html)
first_level_container = frame.css("body")[0].css('div#California_c')[0].css('div')[3]

morenode_img = first_level_container.css("[ct='application/morenode']")[0].css('img')[0]

browser.frame(:name,"contents").element(css: morenode_img.css_path).click

puts "waiting 5 seconds for operation..."
sleep(5)
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
		puts "waiting 3 seconds for operation..."
		sleep(3)
		puts "done waiting"

		#scoot over to the main window
		doc_body = Nokogiri::HTML(browser.frame(:name,"main").frame(:name,"docbody").html)
  
		# grab the chapter's title-- the first one is weird but the rest are same
  		chapter_title = doc_body.css("[class='Chapter']")[0].css('span')[0].text
	
		# originally the index started at ': ' but now ':'
		
		# also need to get the index of '.' because some chapters have that?
		colon_index = chapter_title.index(':')
		period_index = chapter_title.index('.')
		divider_index = 0
		
		if colon_index != nil
			if colon_index < 20
				divider_index = colon_index
			end
		else
			divider_index = period_index
		end
	
		# get the index and text title separated
		chapter_index = chapter_title[(chapter_title.index('R')+2)..(divider_index-1)]
		chapter_name = chapter_title[(divider_index+2)..-1]
		
		puts chapter_index
		puts chapter_name
		
		if i == chapters.length - 2
			chapter_index = "A"
		end
		
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
  		  		if i == 51 && k == 91
  		  		elsif i == 51 && k == 92
  		  		else
  		    		# for each section:
  
				  	# grab and add the section's title
				  	# some of theme are in different formats!
				  	# most are in a span, but a few are just in the h5
			  	
				  	section_title = section1.text.gsub("\n"," ")
				  	
				  	puts section_title
  
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
		  			
		  			section_title_index = section_title_index[0...-2]
		  		
		  			# add section title to new array
			  		section_array = Array.new()
			  		section_array.push(section_title_index)
			  		section_array.push(section_title_text)
		  			sections_array.push(section_array)
		  		
		  			# create a JSON Object for this section
				  	section_object = Hash.new()
		  	
				  	# text
				  	section_object.merge!(:text => section_text1)
		  	
		  			# credits (tag is history but it seems more credit like?)
		  	
				  	# division (identifier and text). use article
		  	
				  	# chapter (identifier and text). use chapter
		  	
		  			# index is usually a period
		  			# like 'SEC. 10.100-373.'
		  			# but sometimes a colon
		  			# like 'Appendix A:'
		  			section_period_index = section_title_index.index('.')
		  	
				  	# heading
				  	section_heading = Hash.new()
				  	if section_period_index != nil
					  	section_heading.merge!(:title => section_title_index[0...section_period_index])
			 		 	section_heading.merge!(:chaptersection => section_title_index[(section_period_index+1)..-1])
			 		else
			 			section_heading.merge!(:title => section_title_index)
			 		end
		 		 	section_heading.merge!(:identifier => section_title_index)
				  	section_heading.merge!(:catch_text => section_title_text)
				  	section_object.merge!(:heading => section_heading)
				  	
		  			# create a file for this section and put in json with title_index
		  			File.open("sections/" + section_title_index + ".json","w") do |f|

						f.write(section_object.to_json)

					end
  				end
  	  	end
  	end
  
  	# at chapter level, if no articles then grab any sections in it
  	if articles.length == 0
  
  	  	sections2 = doc_body.css("[class='Section']") 	
  
	  	sections2.each_with_index do |section2,k|
  		  	# for each section:
  
		  	# grab and add the section's title
		  	section_title2 = section2.css('span')[0].text
		  	
		  	puts section_title2
  
		  	# grab the text inside the section. last one is tricky
		  	if k < sections2.length - 1
			  	paragraphs = collect_between(section2,sections2[k+1])
		  	else
	 		  	paragraphs = collect_between(section2,footer)
	 	#	else
	 			# MAYBE TODO: need case for 29A, where the last paragraph DOESN't have history
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
		  		  	
		  	puts "then..."
		  	puts section_title_index
		  	puts section_title_text
		  	
		  	if i == chapters.length - 2
		  		section_title_text = section_title_text[2..-1]
		  		section_title_index = "A." + section_title_index[0...-1]
		  	else
		  		section_title_index = section_title_index[0...-2]
		  	end
		  	
		  	puts "now..."
		  	puts section_title_index
		  	puts section_title_text
		  		
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
		  	
		  	# index is usually a period
		  	# like 'SEC. 10.100-373.'
		  	# but sometimes a colon
		  	# like 'Appendix A:'
		  	section_period_index = section_title_index.index('.')
		  	
			# heading
			section_heading = Hash.new()
			if section_period_index != nil
			  	section_heading.merge!(:title => section_title_index[0...section_period_index])
			 	section_heading.merge!(:chaptersection => section_title_index[(section_period_index+1)..-1])
			else
				section_heading.merge!(:title => section_title_index)
			end
		  	section_heading.merge!(:identifier => section_title_index)
		  	section_heading.merge!(:catch_text => section_title_text)
		  	section_object.merge!(:heading => section_heading)
		  	
		  	# create a file for this section and put in json with title_index
		  	File.open("sections/" + section_title_index + ".json","w") do |f|

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