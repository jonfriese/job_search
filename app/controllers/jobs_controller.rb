class JobsController < ApplicationController
respond_to :html, :json
  # GET /jobs
  # GET /jobs.json
  def index
    @keywords = params[:keywords].tr(" ", "+")
    @location = params[:location].tr(" ", "")
    github_response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")
    stackoverflow_response = HTTParty.get("http://careers.stackoverflow.com/jobs/feed?searchTerm=#{@keywords}&location=#{@location}&sort=p")
    if %w(ruby rails).any? {|str| params[:keywords].downcase.include? str}
      ruby_now_response = HTTParty.get("http://feeds.feedburner.com/jobsrubynow?format=xml")
      @ruby_now_jobs = manipulate_xml(ruby_now_response)
    else
      @ruby_now_jobs = []
    end
    pre_stackoverflow = Hash.from_xml(stackoverflow_response)
    @github_jobs = JSON.parse(github_response.body)
    @stackoverflow_jobs = manipulate_xml(pre_stackoverflow)
  end
end
