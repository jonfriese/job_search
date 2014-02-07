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
    
    #reddit_jobs
    if @keywords.present?
      reddit_response = HTTParty.get("http://www.reddit.com/r/forhire/search.json?q=#{@keywords}+#{@location}&sort=new&restrict_sr=on&t=month")
      reddit_jobs_pre = JSON.parse(reddit_response.body)["data"]["children"]
      @reddit_jobs = reddit_jobs_pre.select { |job| job["data"]["link_flair_text"] == "Hiring" }
    end
    
    #craigslist_jobs
    if @location.present? && @keywords.present?
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

    #ruby_now_jobs
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

    #stackoverflow_jobs
    stackoverflow_response = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&location=#{@location}")
    pre_stackoverflow = manipulate_xml(Hash.from_xml(stackoverflow_response))

    if @location.present? && params[:remote] == "1"
      stackoverflow_response_remote = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&allowsremote=true")
      pre_stackoverflow_remote = manipulate_xml(Hash.from_xml(stackoverflow_response_remote))
      pre_stackoverflow_remote.each do |job|
        pre_stackoverflow << job
        pre_stackoverflow.uniq! { |job| job["link"] }
      end
    end
    @stackoverflow_jobs = pre_stackoverflow.sort_by { |job| job["updated"] }.reverse

    #authentic_jobs
    authentic_response = HTTParty.get("http://www.authenticjobs.com/api/?api_key=#{ENV["AUTHENTIC_JOBS_API_KEY"]}&method=aj.jobs.search&keywords=#{@keywords}&location=#{@location}&perpage=20&begin_date=#{1.month.ago.to_i}&format=json")
    @authentic_jobs = JSON.parse(authentic_response.body)

    #github_jobs
    github_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")    
    @github_jobs = JSON.parse(github_response.body)

    if @location.present? && params[:remote] == "1"
      github_remote_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=remote")
      github_remote_jobs = JSON.parse(github_remote_response.body)
      github_remote_jobs.each do |job|
        @github_jobs << job
      end      
      @github_jobs.uniq! { |job| job["url"] }
      @github_jobs.each do |job|
        job[:time] = Time.parse(job["created_at"])
      end
      @github_jobs = @github_jobs.sort_by { |job| job[:time] }.reverse
    end

    #we_work_remotely_jobs
    if params[:remote] == "1"
      we_work_remote_response = HTTParty.get("https://weworkremotely.com/categories/2/jobs.rss")
      @we_work_remote_jobs = manipulate_xml(Hash.from_xml(we_work_remote_response))
    end
  end
end
