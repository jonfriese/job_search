class JobsController < ApplicationController
respond_to :html, :json
  # GET /jobs
  # GET /jobs.json
  def index
    @keywords = params[:keywords].tr(" ", "+")
    @location = params[:location].tr(" ", "")
    response = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")
    @jobs = JSON.parse(response.body)
  end
end
