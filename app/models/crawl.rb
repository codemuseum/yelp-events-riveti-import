require 'open-uri'
require 'net/http'

class Crawl < ActiveRecord::Base
  URL = 'http://www.yelp.com/locations?return_url=/events/sf/browse'
  
  
  def self.seed_crawl_if_required
    return if Crawl.first
    Crawl.new(:urls => '').save
  end

  
  def self.update_crawl
    seed_crawl_if_required

    page = Hpricot(open(URL))
    cities = (page/'li.state ul.city li.a')

    report = []

    city_urls = cities.map  { |c| c.attributes['href'] }
    city_urls.each { |city_url| report.concat(parse_events_page(city_url)) }
    
    ####### SEND REPORT  ##### TODO START HERE
    
    report
    
  rescue OpenURI::HTTPError => e
    logger.error "FATAL ERROR: Couldn't open base URL '#{URL}' because of an HTTP Error. #{e}"
    raise
  end
  
  def self.parse_events_page(url, iteration = 0)
    parsed_events = []
    
    begin
      page = Hpricot(open(city_url))
      events = (page/'ul#main_events_list li')
      events.each do |event| 
        result = parse_event_li(event)
        parsed_events << result if result
      end
      
    rescue OpenURI::HTTPError => e
      logger.debug "Couldn't open city: #{city_url} because of an HTTP Error. #{e}"
    rescue StandardError => e
      logger.debug "Couldn't open city: #{city_url}. #{e}"
    end
    
    parsed_events
  end
  
  def self.parse_event_li(event_li)
    url = (event_li/'h2.title a.url')[0].attributes['href']
    
    unless Crawl.first.urls.include?(url)
      return parse_unique_event_url(url)
    else
      return nil
    end
  end
  
  def self.parse_unique_event_url(event_url)
    page = Hpricot(open(event_url))
    
    details = {
      :category => (page/'#main_events dl > dd a')[0].inner_text,
      :name => (page/'h1#event_name').inner_text,
      :url => event_url,
      :start => (page/'.dtstart')[0].attributes['title'],
      :end => nil,
      :timezone => nil,
      :street_address1 => (page/'.street-address')[0].inner_text,
      :street_address2 => nil,
      :city => (page/'.locality')[0].inner_text,
      :state_province_region => (page/'.region')[0].inner_text,
      :zip_postal_code => (page/'.postal-code')[0].inner_text,
      :country => 'US',
      :popularity_rank => (page/'#subscriber_count')[0].inner_text.to_i + (page/'#watching_count')[0].inner_text.to_i
    }
    
    Crawl.first.update_attribute(:urls, "#{event_url}|#{Crawl.first.urls}")
  
    details
    
  rescue StandardError => e
    logger.debug "Couldn't open event: #{event_url}. #{e}"
    nil
  end
  
  
  
  
  def self.send_tweet(msg)
    response = User.consumer.request(:post, "/statuses/update.json?status=#{CGI::escape(msg)}", User.first.access_token, { :scheme => :query_string })
    case response
    when Net::HTTPSuccess
      response.body
    else
      response.error!
      logger.error "--- Failed to sent tweet `#{msg}` via OAuth for #{User.first.user_name}"
    end
  end
  
  def self.build_tweet(title, url, tags)
    if "#{title} #{url}".length > 140
      return "#{title[0..(140-1-url.size)]} #{url}"
    elsif "#{title} #{url} #{tags.join(' ')}".length > 140
      tags_popped = tags.dup
      tags_popped.pop
      return build_tweet(title, url, tags_popped)
    else
      return "#{title} #{url} #{tags.join(' ')}"
    end
  end

end
