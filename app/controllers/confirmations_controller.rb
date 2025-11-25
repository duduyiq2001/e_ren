class ConfirmationsController < ApplicationController
  def pending
    @email = params[:email]
  end
end
