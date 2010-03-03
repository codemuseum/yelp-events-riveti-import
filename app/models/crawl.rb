require 'open-uri'
require 'net/http'

class Crawl < ActiveRecord::Base
  
  URL = 'http://www.yelp.com/locations?return_url=/events/sf/browse'
  CITY_BASE_URL = 'http://www.yelp.com'
  
  
  def self.seed_crawl_if_required
    return if Crawl.first
    Crawl.new(:urls => '').save
  end

  def self.clear_crawl
    Crawl.first.update_attribute(:urls, "")
  end
  
  # You can limit the amount of crawled cities by passing in a number > 0
  def self.update_crawl(limit_crawled_cities = 0)
    seed_crawl_if_required

    page = Hpricot(open(URL))
    logger.debug "Opened #{URL}"
    cities = (page/'li.state ul.cities li a')

    report = []

    city_urls = cities.map  { |c| c.attributes['href'] }
    logger.debug "Found #{city_urls.size} cities."
    
    city_urls = city_urls[0...limit_crawled_cities] if limit_crawled_cities > 0
    
    city_urls.each { |city_url| report.concat(parse_events_page(city_url)) }
    
    ####### SEND REPORT
    Riveti::Api.send_events(report) if report.size > 0
    
    report
    
  rescue OpenURI::HTTPError => e
    logger.error "FATAL ERROR: Couldn't open base URL '#{URL}' because of an HTTP Error. #{e}"
    raise
  end
  
  def self.parse_events_page(url)
    parsed_events = []
    
    begin
      page = Hpricot(open("#{CITY_BASE_URL}#{url}"))
      logger.debug "Opened #{CITY_BASE_URL}#{url}"
      events = (page/'ul#main_events_list li')
      logger.debug "Found #{events.size} events"
      events.each do |event| 
        result = parse_event_li(event)
        parsed_events << result if result
      end
      
    rescue OpenURI::HTTPError => e
      logger.debug "Couldn't open city: #{url} because of an HTTP Error. #{e}"
      # raise
    rescue StandardError => e
      logger.debug "Couldn't open city: #{url}. #{e}"
      # raise
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
    page = Hpricot(open("#{CITY_BASE_URL}#{event_url}"))
    # Make nil checking easier
    category = (page/'#main_events dl > dd a')[0]
    postal_code = (page/'.postal-code')[0]
    street_address1 = (page/'.street-address')[0]
    locality = (page/'.locality')[0]
    dtstart = (page/'.dtstart')[0]
    region = (page/'.region')[0]
    subscriber_count = (page/'#subscriber_count')[0]
    watching_count = (page/'#watching_count')[0]
    picture = (page/'#main_event_photo img')[0]
    
    details = {
      :category_name => category ? category.inner_text : nil,
      :name => (page/'h1#event_name').inner_text,
      :description => truncate((page/'#event_description').inner_text.strip, 255),
      :url => "#{CITY_BASE_URL}#{event_url}",
      :start => dtstart ? dtstart.attributes['title'] : nil,
      :end => nil,
      :timezone => nil,
      :street_address1 => street_address1 ? street_address1.inner_text : nil,
      :street_address2 => nil,
      :city => locality ? locality.inner_text : nil,
      :state_province_region => region ? region.inner_text : nil,
      :zip_postal_code =>  postal_code ? postal_code.inner_text : nil,
      :country => 'US',
      :popularity_rank => 
        (subscriber_count ? subscriber_count.inner_text.to_i : 0) + (watching_count ? watching_count.inner_text.to_i : 0),
      :picture_hotlink => picture ? picture.attributes['src'] : nil
    }
    
    Crawl.first.update_attribute(:urls, "#{event_url}|#{Crawl.first.urls}")
  
    details
    
  # rescue StandardError => e
  #   logger.debug "Couldn't open event: #{event_url}. #{e}"
  #   nil
  end
  
  def self.truncate(text, *args)
    options = args.extract_options!
    unless args.empty?
      ActiveSupport::Deprecation.warn('truncate takes an option hash instead of separate ' +
      'length and omission arguments', caller)

      options[:length] = args[0] || 30
      options[:omission] = args[1] || "..."
    end
    options.reverse_merge!(:length => 30, :omission => "...")

    if text
      l = options[:length] - options[:omission].mb_chars.length
      chars = text.mb_chars
      (chars.length > options[:length] ? chars[0...l] + options[:omission] : text).to_s
    end
  end
end
