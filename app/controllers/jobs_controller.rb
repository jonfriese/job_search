class JobsController < ApplicationController

  require 'rss'
  require 'open-uri'
  require 'actionpack/action_caching'
  respond_to :html, :json
  caches_action :index, :cache_path => Proc.new { |c| c.request.url }, :expires_in => 10.minute


  def index
    if params[:remote] == 1
      @remote = 'true'
    else
      @remote = 'false'
    end
    @keywords = params[:keywords].tr(" ", "+").gsub("#", "%23")
    @location = params[:location].tr(" ", "")
    
    #Reddit needs keywords or else it will search all kinds of jobs and we need to filter out 'For Hire' posts
    if @keywords.present?
      reddit_response = HTTParty.get("http://www.reddit.com/r/forhire/search.json?q=#{@keywords}+#{@location}&sort=new&restrict_sr=on&t=month")
      reddit_jobs_pre = JSON.parse(reddit_response.body)["data"]["children"]
      @reddit_jobs = reddit_jobs_pre.select { |job| job["data"]["link_flair_text"] == "Hiring" }
    end
    
    #get jobs from Craigslist
    if @location.present?
      begin
        craigslist_url = "http://#{@location}.craigslist.org/search/jjj?catAbb=jjj&query=#{@keywords}&s=0&format=rss"
        open(craigslist_url) do |rss|
          @craigslist_jobs = RSS::Parser.parse(rss).items
        end
      rescue SocketError
        @craigslist_jobs = []
      rescue OpenURI::HTTPError
        @craigslist_jobs = []
      rescue RSS::NotWellFormedError
        @craigslist_jobs = []
      end
    end

    #get jobs from Ruby Now if search contains Ruby or Rails
    if %w(ruby rails).any? {|str| params[:keywords].downcase.include? str} || params[:keywords].empty?
      ruby_now_response = HTTParty.get("http://feeds.feedburner.com/jobsrubynow?format=xml")
      if @location.empty?
        @ruby_now_jobs = manipulate_xml(ruby_now_response)
      else
        @ruby_now_jobs = []
        @now_jobs = manipulate_xml(ruby_now_response)
        @now_jobs.map do |job|
          if job['title'].downcase.include? params[:location].downcase
            @ruby_now_jobs << job
          end
        end
      end
    else
      @ruby_now_jobs = []
    end

    stackoverflow_response = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&location=#{@location}")
    pre_stackoverflow = manipulate_xml(Hash.from_xml(stackoverflow_response))

    if @location.present? && params[:remote] == "1"
      stackoverflow_response_remote = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?allowsremote=true")
      pre_stackoverflow_remote = manipulate_xml(Hash.from_xml(stackoverflow_response_remote))
      pre_stackoverflow_remote.each do |job|
        pre_stackoverflow << job
      end
    end

    @stackoverflow_jobs = pre_stackoverflow.sort_by { |job| job["updated"] }.reverse

    authentic_response = HTTParty.get("http://www.authenticjobs.com/api/?api_key=#{ENV["AUTHENTIC_JOBS_API_KEY"]}&method=aj.jobs.search&keywords=#{@keywords}&location=#{@location}&perpage=20&begin_date=#{1.month.ago.to_i}&format=json")
    @authentic_jobs = JSON.parse(authentic_response.body)

    github_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")    
    @github_jobs = JSON.parse(github_response.body)

    we_work_remote_response = HTTParty.get("https://weworkremotely.com/categories/2/jobs.rss")
    @we_work_remote_jobs = manipulate_xml(Hash.from_xml(we_work_remote_response))
  end
end
