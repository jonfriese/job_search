class JobsController < ApplicationController
respond_to :html, :json
  # GET /jobs
  # GET /jobs.json
  def index
    @keywords = params[:keywords].tr(" ", "+")
    @location = params[:location].tr(" ", "")
    @jobs = HTTParty.get("http://jobs.github.com/positions.json?description=#{@keywords}&location=#{@location}")
    respond_with(@jobs) do |format|
      format.json { render json: @jobs } 
    end
  end
end
