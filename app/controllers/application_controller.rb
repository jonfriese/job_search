class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def manipulate_stackoverflow_xml(data)
  	x = data["rss"]
  	y = x["channel"]
  	if y["totalResults"] == "0"
  		return []
  	else
  		all_items = y["item"]
  	end
  end
end
