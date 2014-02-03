class JobsController < ApplicationController
respond_to :html, :json
require 'rss'
require 'open-uri'
  # GET /jobs
  # GET /jobs.json
  def index
    @keywords = params[:keywords].tr(" ", "+")
    @location = params[:location].tr(" ", "")
    github_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")
    stackoverflow_response = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&location=#{@location}")
    authentic_response = HTTParty.get("http://www.authenticjobs.com/api/?api_key=#{ENV["AUTHENTIC_JOBS_API_KEY"]}&method=aj.jobs.search&keywords=#{@keywords}&location=#{@location}&perpage=20&begin_date=#{1.week.ago.to_i}&format=json")
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
      end
    end
    if %w(ruby rails).any? {|str| params[:keywords].downcase.include? str}
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
    @authentic_jobs = JSON.parse(authentic_response.body)
    @github_jobs = JSON.parse(github_response.body)
    @stackoverflow_jobs = manipulate_xml(pre_stackoverflow).sort_by { |job| job["updated"] }.reverse
  end
end
