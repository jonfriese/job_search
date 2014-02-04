class JobsController < ApplicationController

  require 'rss'
  require 'open-uri'
  require 'actionpack/action_caching'
  respond_to :html, :json
  caches_action :index, :cache_path => Proc.new { |c| c.request.url }, :expires_in => 10.minute


  def index
    @keywords = params[:keywords].tr(" ", "+").gsub("#", "%23")
    @location = params[:location].tr(" ", "")
    github_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")
    stackoverflow_response = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&location=#{@location}")
    reddit_response = HTTParty.get("http://www.reddit.com/r/forhire/search.json?q=#{@keywords}+#{@location}&sort=new&restrict_sr=on&t=week")
    authentic_response = HTTParty.get("http://www.authenticjobs.com/api/?api_key=#{ENV["AUTHENTIC_JOBS_API_KEY"]}&method=aj.jobs.search&keywords=#{@keywords}&location=#{@location}&perpage=20&begin_date=#{1.week.ago.to_i}&format=json")
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
    pre_stackoverflow = Hash.from_xml(stackoverflow_response)
    @stackoverflow_jobs = manipulate_xml(pre_stackoverflow).sort_by { |job| job["updated"] }.reverse
    @authentic_jobs = JSON.parse(authentic_response.body)
    @reddit_jobs = JSON.parse(reddit_response.body)
    @github_jobs = JSON.parse(github_response.body)
  end
end
