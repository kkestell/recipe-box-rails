class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ help home ]

  def help
  end

  def home
  end
end
