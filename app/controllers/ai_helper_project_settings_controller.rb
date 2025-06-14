# frozen_string_literal: true
# This controller manages AI helper project settings in Redmine.
class AiHelperProjectSettingsController < ApplicationController
  layout "base"
  before_action :find_user, :find_project, :authorize, :find_settings

  # Update AI helper project settings
  def update
    @settings.attributes = params.require(:setting).permit(:issue_draft_instructions, :subtask_instructions, :lock_version)
    begin
      if @settings.save
        flash[:notice] = l(:notice_successful_update)
      else
        flash[:error] = @settings.errors.full_messages.join(",")
      end
    rescue ActiveRecord::StaleObjectError
      flash[:error] = l(:notice_locking_conflict)
    end
    redirect_to :controller => "projects", :action => "settings", :id => @project, :tab => "ai_helper"
  end

  private

  # Find the project based on the ID parameter
  def find_settings
    @settings = AiHelperProjectSetting.settings(@project)
  end

  # Find user based on the current session
  def find_user
    @user = User.current
  end
end
